# frozen_string_literal: true

class CodeReviewAssignmentsController < ApplicationController
  include RedmineCodeReview::RedirectToReview

  before_filter :find_project_by_project_id, :authorize

  def new
    code = {}

    issue = { subject: l(:code_review_requrest) }
    issue[:tracker_id] = settings.assignment_tracker_id if settings.assignment_tracker_id

    if attachment_id = params[:attachment_id].presence

      attachment = Attachment.find(attachment_id)

      code[:action_type] = 'attachment'
      code[:attachment_id] = attachment_id
      issue[:subject] << " [#{attachment.filename}]"
    else

      code[:action_type] = params[:action_type] unless params[:action_type].blank?
      code[:repository_id] = repository.id

      code[:rev] =       params[:rev]       unless params[:rev].blank?
      code[:rev_to] =    params[:rev_to]    unless params[:rev_to].blank?
      code[:path] =      params[:path]      unless params[:path].blank?
      code[:change_id] = params[:change_id] unless params[:change_id].blank?

      changeset_id = params[:changeset_id].presence
      if changeset_id.nil? and code[:change_id]
        changeset_id = Change.find(code[:change_id]).changeset_id
      end

      if changeset_id
        code[:changeset_id] = changeset_id
        changeset = repository.changesets.find changeset_id
        issue[:subject] << " [#{changeset.text_tag}: #{changeset.short_comments}]" if changeset
      end

    end

    redirect_to new_project_issue_path(@project, issue: issue, code: code)
  end

  def show
    assignment = CodeReviewAssignment.find params[:id]
    # basic sanity check since assignments do not have a project id
    @project.issues.visible.find assignment.issue_id

    # FIXME why do we check for path here? does that mean the same as
    # attachment.blank?
    if assignment.path
      redirect_to_review(assignment)
    else
      # TODO is there a use case for this?
      redirect_to issue_path(assignment.issue)
    end
  end

  private

  def settings
    @settings ||= CodeReviewProjectSetting.find_or_create(@project)
  end

  def repository
    @repository ||= begin
      repository = if params[:repository_id].present?
        @project.repositories.find_by_identifier_param(params[:repository_id])
      else
        @project.repository
      end
      repository || raise(ActiveRecord::RecordNotFound)
    end
  end

end
