# Code Review plugin for Redmine
# Copyright (C) 2009-2011  Haruyuki Iida
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

class CodeReviewIssueHooks < Redmine::Hook::ViewListener
  include RepositoriesHelper

  def view_issues_show_details_bottom(context = {})
    project = context[:project]
    issue = context[:issue]

    if project and User.current.allowed_to?(:view_code_review, project)

      context[:hook_caller].send(
        :render,
        partial: 'hooks/redmine_code_review/issues_show_details_bottom',
        locals: {
          project: project, issue: issue,
          review: issue.code_review,
          assignment: issue.code_review_assignment
        }
      )
    end
  end

  def view_issues_form_details_bottom(context)
    if code = context[:request].parameters[:code]
      fields = %i(rev rev_to path action_type change_id changeset_id attachment_id repository_id).map do |field|
        if value = code[field].presence
          hidden_field_tag "code[#{field}]", value
        end
      end.compact
      safe_join fields, "\n".html_safe
    end
  end

  def controller_issues_new_after_save(context = { })
    if context[:request] && context[:project] && context[:issue]
      request = context[:request]
      parameters = request.parameters
      code = parameters[:code]
      return unless code
      issue = context[:issue]
      issue_id = issue.id

      assignment = CodeReviewAssignment.new
      assignment.issue_id = issue_id
      assignment.change_id = code[:change_id].to_i unless code[:change_id].blank?
      assignment.changeset_id = code[:changeset_id].to_i unless code[:changeset_id].blank?
      assignment.attachment_id = code[:attachment_id].to_i unless code[:attachment_id].blank?
      assignment.file_path = code[:path] unless code[:path].blank?
      assignment.rev = code[:rev] unless code[:rev].blank?
      assignment.rev_to = code[:rev_to] unless code[:rev_to].blank?
      assignment.action_type = code[:action_type] unless code[:action_type].blank?
      assignment.save!
    end
  end

  private
  # FIXME dead code?
  def create_review_info(project, review)
    o = '<tr>'
    o << "<td><b>#{l(:code_review)}:</b></td>"
    o << '<td colspan="3">'
    o << link_to("#{review.repository_identifier + ':' if review.repository_identifier}#{review.path}#{'@' + review.revision if review.revision}:line #{review.line}",
      :controller => 'code_review', :action => 'show', :id => project, :review_id => review.id, :repository_id => review.repository_identifier)
    o << '</td>'
    o << '</tr>'
    return o
  end

  # FIXME dead code?
  def create_assignment_info(project, assignment)
    repository_id = assignment.repository_identifier
    o = '<tr>'
    o << "<td><b>#{l(:review_assigned_for)}:</b></td>"
    o << '<td colspan="3">'
    if assignment.path
      o << link_to("#{repository_id + ':' if repository_id}#{assignment.path}#{'@' + assignment.revision if assignment.revision}",
                   code_review_assignment_path(project, assignment, repository_id: repository_id))
    elsif assignment.revision
      repo = project unless repository_id
      repo ||= assignment.repository
      o << l(:label_revision) + " " + link_to_revision(assignment.revision, repo)
    elsif assignment.attachment
      attachment = assignment.attachment
      o << link_to(attachment.filename, :controller => 'attachments', :action => 'show', :id => attachment.id)
    end
    o << '</td>'
    o << '</tr>'
    return o
  end
end
