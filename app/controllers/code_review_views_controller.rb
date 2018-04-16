class CodeReviewViewsController < ApplicationController
  include RedmineCodeReview::FindRepository
  include RedmineCodeReview::FindChange

  before_filter :find_project_by_project_id, :authorize

  def update_revisions_view
    changeset_ids = params[:changeset_ids].to_s.split(',')
    changeset_ids.reject!(&:blank?)
    @changesets = repository.changesets.find changeset_ids
    render partial: 'update_revisions'
  end


  def update_diff_view
    find_review_if_present

    @repository = repository

    @rev_to = params[:rev_to].presence
    @path   = params[:path].presence
    @action_type = params[:action_type]

    if id = params[:changeset_id].presence
      @changeset = repository.changesets.find id
      @rev = @changeset.revision
    else
      @rev    = params[:rev].presence
      @changeset = repository.find_changeset_by_name(@rev)
    end

    @reviews = CodeReview.where(project: @project, rev: @rev).joins(:issue)

    diff_all = @path.blank? || @path == '.'

    unless diff_all
      @reviews = @reviews.where file_path: @path
      @change = find_change @changeset, @path
    end
  end


  def update_attachment_view
    find_review_if_present

    @attachment = Attachment.find params[:attachment_id]
    @attachment_id = @attachment.id
    @review = CodeReview.new

    @reviews = CodeReview.where(project: @project, attachment: @attachment)

    render 'update_diff_view'
  end

  private

  def find_review_if_present
    if id = params[:review_id].presence
      @show_review = CodeReview.where(project: @project).find_by_id id
    end
  end
end

