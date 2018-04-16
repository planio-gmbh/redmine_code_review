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
        # TODO do we want that?
        # This introduces different behavior for reviews created on the
        # revision page showing all diffs (diff_all) vs the single file diff.
        # We could simply always redirect to the single file diff, regardless
        # of where the review was created?
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
