# frozen_string_literal: true

module RedmineCodeReview
  module RedirectToReview

    def redirect_to_review(target)
      parameters = {}
      parameters[:review_id] = target.id if target.is_a?(CodeReview)

      if attachment = target.attachment
        parameters[:filename] = attachment.filename
        redirect_to attachment_path attachment, parameters

      else
        parameters.update(
          controller: 'repositories', action: target.action_type,
          id: @project, repository_id: @repository_id,
          rev: target.revision,
        )
        unless target.diff_all
          parameters[:path] = URI.decode target.path
        end
        if target.rev_to.present?
          parameters[:rev_to] = target.rev_to 
        end

        redirect_to url_for parameters
      end

    end
  end
end