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
    new_or_create

    if params[:change_id].present?
      @review.change = Change.find(params[:change_id])
    end
    if params[:line].present?
      @review.line = params[:line].to_i
    end

    if (@review.changeset and @review.changeset.user_id)
      @review.issue.assigned_to_id = @review.changeset.user_id
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

    CodeReview.transaction do

      @review.issue.save!
      if @review.changeset
        @review.changeset.issues.each {|issue|
          create_relation @review, issue, settings.issue_relation_type
        } if settings.auto_relation?
      elsif @review.attachment and @review.attachment.container_type == 'Issue'
        issue = Issue.find_by_id(@review.attachment.container_id)
        create_relation @review, issue, settings.issue_relation_type if settings.auto_relation?
      end
      watched_users = []
      @review.open_assignment_issues(User.current.id).each {|issue|
        unless @review.issue.parent_id == issue.id
          create_relation @review, issue, IssueRelation::TYPE_RELATES
        end
        unless watched_users.include?(issue.author)
          watcher = Watcher.new
          watcher.watchable_id = @review.issue.id
          watcher.watchable_type = 'Issue'
          watcher.user = issue.author
          watcher.save!
          watched_users.push(watcher.user)
        end
      }
      @review.save!

    end

  rescue ActiveRecord::RecordInvalid => e
    logger.error e
  end


  def show
    @review = CodeReview.find params[:id]

    @repository = @review.repository
    @issue = @review.issue
    @allowed_statuses = @review.issue.new_statuses_allowed_to(User.current)
    @repository_id = @review.repository_identifier

    if !request.xhr? and params[:update].blank? and @review.path.present?
      redirect_to_review @review
    end
  end

  def reply
    @review = CodeReview.find(params[:id].to_i)
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
    @review = CodeReview.find(params[:id].to_i)
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
    @review = CodeReview.where(project: @project).find params[:id]
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


  def get_parent_candidate(revision)
    changeset = repository.find_changeset_by_name(revision)
    changeset.issues.each {|issue|
      return Issue.find(issue.parent_issue_id) if issue.parent_issue_id
    }
    nil
  end

  def create_relation(review, issue, type)
    return unless issue.project == @project
    relation = IssueRelation.new
    relation.relation_type = type
    relation.issue_from_id = review.issue.id
    relation.issue_to_id = issue.id
    relation.save
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
    @review.rev = params[:rev] unless params[:rev].blank?
    @review.rev_to = params[:rev_to] unless params[:rev_to].blank?
    @review.file_path = params[:path] unless params[:path].blank?
    @review.file_count = params[:file_count].to_i unless params[:file_count].blank?
    @review.attachment_id = params[:attachment_id].to_i unless params[:attachment_id].blank?
    @issue = @review.issue
    @review.issue.safe_attributes = params[:issue] unless params[:issue].blank?
    @review.diff_all = (params[:diff_all] == 'true')

    @parent_candidate = get_parent_candidate(@review.rev) if  @review.rev
  end
end
