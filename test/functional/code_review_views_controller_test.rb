require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class CodeReviewViewsControllerTest < Redmine::ControllerTest
  fixtures :code_reviews, :projects, :users, :repositories,
  :changesets, :changes, :members, :member_roles, :roles, :issues, :issue_statuses,
  :enumerations, :issue_categories, :trackers, :projects, :projects_trackers,
  :code_review_project_settings, :attachments, :code_review_assignments,
  :code_review_user_settings

  setup do
    Project.find(1).enabled_modules.create! name: 'issue_tracking' rescue nil
    Project.find(1).enabled_modules.create! name: 'code_review' rescue nil
    User.current = nil

    Role.all.each {|role|
      role.permissions << :view_code_review
      role.save
    }

    @request.session[:user_id] = 1
  end


  test "should update_diff_view" do
    review_id = 9
    review = CodeReview.find(review_id)
    assert_equal('Unable to print recipes', review.comment)
    xhr :get, :update_diff_view, project_id: 'ecookbook',
                                 review_id: review_id,
                                 rev: 1,
                                 path: '/test/some/path/in/the/repo'
    assert_response :success
  end


  test "should update_attachment_view" do
    review_id = 9
    review = CodeReview.find(review_id)
    assert_equal('Unable to print recipes', review.comment)
    xhr :get, :update_attachment_view, project_id: 'ecookbook', attachment_id: 1
    assert_response :success
  end


  test "should update revisions view without changeset ids" do
    get :update_revisions_view, project_id: 'ecookbook'
    assert_response :success
    assert_equal 0, assigns(:changesets).length
  end

  test "should update revisions view with changeset ids" do
    get :update_revisions_view, project_id: 'ecookbook', changeset_ids: '101,102,103'
    assert_response :success
    assert_equal(3, assigns(:changesets).length)
  end
end
