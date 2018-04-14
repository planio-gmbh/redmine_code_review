require_relative '../test_helper'

class CodeReviewAssignmentsTest < Redmine::IntegrationTest
  fixtures :code_reviews, :projects, :users, :repositories,
  :changesets, :changes, :members, :member_roles, :roles, :issues, :issue_statuses,
  :enumerations, :issue_categories, :trackers, :projects, :projects_trackers,
  :code_review_project_settings, :attachments, :code_review_assignments,
  :code_review_user_settings

  setup do
    Project.find(1).enabled_modules.create! name: 'issue_tracking' rescue nil
    Project.find(1).enabled_modules.create! name: 'code_review' rescue nil
    User.current = nil
  end

  test "new should redirect for attachment assignment" do
    att = Attachment.first
    log_user 'admin', 'admin'
    get "/projects/ecookbook/code_review_assignments/new", { attachment_id: att.id }
    assert_redirected_to "/projects/ecookbook/issues/new?code%5Baction_type%5D=attachment&code%5Battachment_id%5D=#{att.id}&issue%5Bsubject%5D=Review+request+%5Berror281.txt%5D"

    follow_redirect!
    assert_response :success
    assert_select "input#code_attachment_id[value='#{att.id}']"
  end

  test "new should redirect for changeset assignment" do
    cs = Changeset.first
    log_user 'admin', 'admin'
    get "/projects/ecookbook/code_review_assignments/new", { changeset_id: cs.id, action_type: 'revision' }
    assert_redirected_to "/projects/ecookbook/issues/new?code%5Baction_type%5D=revision&code%5Bchangeset_id%5D=#{cs.id}&code%5Brepository_id%5D=#{cs.repository_id}&issue%5Bsubject%5D=Review+request+%5Bcommit%3A691322a8eb01e11fd7%3A+My+very+first+commit+do+not+escaping+%23%3C%3E%26%5D"

    follow_redirect!
    assert_response :success
    assert_select "input#code_changeset_id[value='#{cs.id}']"
    assert_select "input#code_repository_id[value='#{cs.repository_id}']"
    assert_select "input#code_action_type[value='revision']"
  end

  test "should show revision path assignment" do
    log_user 'admin', 'admin'
    get "/projects/ecookbook/code_review_assignments/1"
    assert_redirected_to "/projects/ecookbook/repository/revisions/1/diff/MyString"
  end

  test "should show attachment assignment" do
    log_user 'admin', 'admin'
    get "/projects/ecookbook/code_review_assignments/2"
    assert_redirected_to "/issues/2"
  end
end

