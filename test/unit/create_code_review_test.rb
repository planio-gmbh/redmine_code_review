require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class CreateCodeReviewTest < ActiveSupport::TestCase
  fixtures :projects,
    :users,
    :repositories,
    :attachments,
    :changesets,
    :changes,
    :trackers,
    :projects_trackers,
    :workflows,
    :issue_statuses,
    :enumerations

  setup do
    @project = Project.find 'ecookbook'
    @user = User.find 1
  end

  def setup_review(action_type, review_params = {})
    review = CodeReview.new
    review.issue = Issue.new
    review.issue.tracker_id = 1

    review.assign_attributes review_params
    review.project_id = @project.id
    review.issue.project_id = @project.id

    review.user_id = @user.id
    review.updated_by_id = @user.id
    review.issue.start_date ||= Date.today if Setting.default_issue_start_date_to_creation_date?

    review.action_type = action_type
    review.diff_all = false

    #@review.rev = params[:rev] unless params[:rev].blank?
    #@review.rev_to = params[:rev_to] unless params[:rev_to].blank?
    #@review.file_path = params[:path] unless params[:path].blank?
    #@review.file_count = params[:file_count].to_i unless params[:file_count].blank?
    #@review.attachment_id = params[:attachment_id].to_i unless params[:attachment_id].blank?
    #review.issue.safe_attributes = 

    review
  end

  test "should create review" do
    review = setup_review(
      'diff',
      {comment: 'aaa', subject: 'bbb', line: 1, change_id: 1}
    )

    r = nil
    assert_difference 'CodeReview.count' do
      assert_difference 'Issue.count' do
        r = RedmineCodeReview::CreateCodeReview.(@project, review, user: @user)
      end
    end
    assert r.review_created?
    assert review = r.review
    assert issue = review.issue
    assert_equal 'bbb', review.subject
    assert_equal 'aaa', review.comment
    assert_equal @user, review.user
    assert_equal 1, review.line
    assert_equal 1, review.change_id
    assert_equal @project.id, review.project_id
  end

  test "should create review for changeset with related issue" do
    change = Change.find(3)
    changeset = change.changeset
    cs_issue = Issue.generate!(project: @project)
    changeset.issues << cs_issue
    changeset.save

    review = setup_review(
      'diff',
      {comment: 'aaa', subject: 'bbb', line: 1, change_id: change.id}
    )

    r = nil
    assert_difference 'CodeReview.count' do
      assert_difference 'Issue.count' do
        r = RedmineCodeReview::CreateCodeReview.(@project, review, user: @user)
      end
    end
    assert r.review_created?
    assert review = r.review
    assert issue = review.issue
    assert rel = issue.relations_to.first
    assert_equal cs_issue, rel.issue_from
    assert_equal IssueRelation::TYPE_RELATES, rel.relation_type
  end

end
