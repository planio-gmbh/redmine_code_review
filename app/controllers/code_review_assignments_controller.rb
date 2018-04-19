# frozen_string_literal: true

class CodeReviewAssignmentsController < ApplicationController
  include RedmineCodeReview::RedirectToReview
  include RedmineCodeReview::FindRepository
  include RedmineCodeReview::FindSettings

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

      code[:action_type] = params[:action_type].presence
      code[:repository_id] = repository.id

      code[:rev] =       params[:rev]       unless params[:rev].blank?
      code[:rev_to] =    params[:rev_to]    unless params[:rev_to].blank?
      code[:path] =      params[:path]      unless params[:path].blank?
      code[:change_id] = params[:change_id] unless params[:change_id].blank?

      changeset_id = params[:changeset_id].presence
      # TODO we *should* always have params[:changeset_id], so the next two ifs
      # are not needed
      if changeset_id.nil? and code[:change_id]
        changeset_id = Change.find(code[:change_id]).changeset_id
      end

      if changeset_id.nil? and
         code[:rev] and
         changeset = repository.find_changeset_by_name(code[:rev])

        changeset_id = changeset.id
      end

      code[:changeset_id] = changeset_id
      changeset ||= repository.changesets.find changeset_id

      if code[:action_type] == 'entry'
        issue[:subject] << " [#{code[:path]}@#{changeset.text_tag}]"
      elsif code[:path] and code[:path] != '.'
        issue[:subject] << " [#{code[:path]}@#{changeset.text_tag}: #{changeset.short_comments}]"
      else
        issue[:subject] << " [#{changeset.text_tag}: #{changeset.short_comments}]"
      end

    end

    redirect_to new_project_issue_path(@project, issue: issue, code: code)
  end

  def show
    assignment = CodeReviewAssignment.find params[:id]
    # basic sanity check since assignments do not have a project id
    @project.issues.visible.find assignment.issue_id

    redirect_to_review assignment, repository
  end


end
