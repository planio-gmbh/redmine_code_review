module CodeReviewViewsHelper
  include RedmineCodeReview::ShowAssignmentsHelper

  def progress_for_changeset(changeset)
    progress = if changeset.review_count > 0
      content_tag(:span, style: "white-space: nowrap") do
        progress_bar(
          [changeset.closed_review_pourcent, changeset.completed_review_pourcent],
          :width => '60px',
          :legend => "#{changeset.closed_review_count}/#{changeset.review_count} #{l(:label_closed_issues)}"
        )
      end

    elsif changeset.assignment_count > 0
      if (changeset.open_assignment_count > 0)
        l(:code_review_assigned)
      else
        l(:code_review_reviewed)
      end

    elsif User.current.allowed_to?(:assign_code_review, @project)
      content_tag(:span, style: "white-space: nowrap") do
        l(:lable_no_code_reviews)
      end + ':'.html_safe +
      content_tag(:span, style: "white-space: nowrap") do
        link_to(l(:label_assign_review),
                new_code_review_assignment_path(@project,
                                                rev: changeset.revision,
                                                changeset_id: changeset.id))
      end
    end

    content_tag(:p, class: "progress-info", style: "white-space: nowrap;") do
      progress
    end if progress
  end
end
