module RedmineCodeReview
  module ShowAssignmentsHelper

    def show_assignments(assignments, project, options = {})
      links = if assignments
        assignments.map do |assignment|
          link_to_issue assignment.issue, subject: false, tracker: false
        end
      else
        []
      end

      links << link_to(
        l(:button_add), new_code_review_assignment_path(project, options),
        class: 'icon icon-add'
      )

      safe_join links
    end

  end
end
