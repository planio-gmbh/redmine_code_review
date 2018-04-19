# Code Review plugin for Redmine
# Copyright (C) 2009-2015 Haruyuki Iida
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class CodeReviewsController < ApplicationController
  include RedmineCodeReview::RedirectToReview
  include RedmineCodeReview::FindChange
  include RedmineCodeReview::FindRepository
  include RedmineCodeReview::FindSettings

  before_filter :find_project_by_project_id, :authorize

  helper :sort
  include SortHelper
  helper :journals
  helper :projects
  include ProjectsHelper
  helper :issues
  include IssuesHelper
  helper :code_review
  include CodeReviewHelper
  helper :custom_fields
  include CustomFieldsHelper

  def index
    sort_init "#{Issue.table_name}.id", 'desc'
    sort_update ["#{Issue.table_name}.id", "#{Issue.table_name}.status_id", "#{Issue.table_name}.subject",  "path", "updated_at", "user_id", "#{Changeset.table_name}.committer", "#{Changeset.table_name}.revision"]

    limit = per_page_option

    query = RedmineCodeReview::CodeReviewsQuery.new(@project, limit, params)
    @review_count = query.count
    @show_closed = query.show_closed?

    @review_pages = Paginator.new @review_count, limit, params['page']

    @reviews = query.scope.order(sort_clause)
      .limit(limit).offset(@review_pages.offset)

    render layout: !request.xhr?
  end

  def new
    @change = find_change changeset, params[:path].presence

    new_or_create
    @review.change = @change if @change

    if params[:line].present?
      @review.line = params[:line].to_i
    end

    if (changeset and changeset.user_id)
      @review.issue.assigned_to_id = changeset.user_id
    end

    @default_version_id = @review.issue.fixed_version.id if @review.issue.fixed_version

    if @default_version_id.nil? and
      @review.changeset and
      issue = @review.changeset.issues.detect{|i| i.fixed_version.present?}

      @default_version_id = issue.fixed_version.id
    end

    if @default_version_id.nil? and
      issue = @review.open_assignment_issues(User.current.id).detect{|i|
        i.fixed_version.present?
      }

      @default_version_id = issue.fixed_version.id
    end
  end


  def create
    new_or_create
    r = RedmineCodeReview::CreateCodeReview.(@project, @review)
    unless r.review_created?
      logger.error r.error
    end
  end


  def show
    @review = find_code_review

    @repository = @review.repository
    @issue = @review.issue
    @allowed_statuses = @review.issue.new_statuses_allowed_to(User.current)
    @repository_id = @review.repository_identifier

    if !request.xhr? and params[:update].blank? and @review.path.present?
      redirect_to_review @review, @repository
    end
  end

  def reply
    @review = find_code_review
    @issue = @review.issue
    @issue.lock_version = params[:issue][:lock_version]
    comment = params[:reply][:comment]
    journal = @issue.init_journal(User.current, comment)
    @review.assign_attributes(params[:review])
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)

    @issue.save!
    if !journal.new_record?
      # Only send notification if something was actually changed
      flash[:notice] = l(:notice_successful_update)
    end

  rescue ActiveRecord::StaleObjectError
    # Optimistic locking exception
    @error = l(:notice_locking_conflict)
  end

  def update
    @review = find_code_review
    @review.issue.init_journal(User.current, nil)
    @allowed_statuses = @review.issue.new_statuses_allowed_to(User.current)
    @issue = @review.issue
    @issue.lock_version = params[:issue][:lock_version]
    @review.lock_version = params[:review][:lock_version]
    @review.assign_attributes(params[:review])
    @review.updated_by_id = User.current.id

    CodeReview.transaction do
      if @review.save and @issue.save
        @notice = l(:notice_review_updated)
        @success = true
      else
        raise ActiveRecord::Rollback
      end
    end
  rescue ActiveRecord::StaleObjectError
    # Optimistic locking exception
    @error = l(:notice_locking_conflict)
  end

  def destroy
    @review = find_code_review
    @review.issue.destroy # review is destroyed through dependend: destroy
  end

  def forward_to_revision
    path = params[:path]
    rev = params[:rev]
    changesets = repository.latest_changesets(path, rev, Setting.repository_log_display_limit.to_i)
    change = changesets[0]

    identifier = change.identifier
    redirect_to url_for(:controller => 'repositories', :action => 'entry', :id => @project, :repository_id => repository.identifier_param) + '/' + path + '?rev=' + identifier.to_s

  end

  def preview
    @text = (params[:reply] || params[:review])[:comment]
    render partial: 'common/preview'
  end


  private

  def find_code_review
    CodeReview.where(project: @project).find params[:id]
  end


  def changeset
    @changeset ||= if @change
      @change.changeset
    elsif params[:changeset_id]
      repository.changesets.find params[:changeset_id]
    elsif rev = params[:rev].presence
      repository.find_changeset_by_name(rev)
    end

  end


  def get_parent_candidate
    changeset.issues.detect{|issue|
      issue.parent_issue.present?
    }.try :parent_issue if changeset
  end

  # initializes data used for new and create
  # TODO make that nicer
  def new_or_create
    @tracker_in_review_dialog = settings.tracker_in_review_dialog
    @review = CodeReview.new
    @review.issue = Issue.new

    if params[:issue] and params[:issue][:tracker_id]
      @review.issue.tracker_id = params[:issue][:tracker_id].to_i
    else
      @review.issue.tracker_id = settings.tracker_id
    end
    @review.assign_attributes(params[:review])
    @review.project_id = @project.id
    @review.issue.project_id = @project.id

    @review.user_id = User.current.id
    @review.updated_by_id = User.current.id
    @review.issue.start_date ||= Date.today if Setting.default_issue_start_date_to_creation_date?
    @review.action_type = params[:action_type]
    @review.rev = params[:rev].presence
    @review.rev ||= @change.revision if @change
    @review.rev_to = params[:rev_to].presence
    @review.file_path = params[:path].presence
    @review.file_count = params[:file_count].to_i if params[:file_count].present?
    @review.attachment_id = params[:attachment_id].presence
    @issue = @review.issue
    @review.issue.safe_attributes = params[:issue] if params[:issue]
    @review.diff_all = (params[:diff_all] == 'true')

    @parent_candidate = get_parent_candidate
  end

end
