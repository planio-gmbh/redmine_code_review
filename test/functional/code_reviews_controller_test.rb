# Code Review plugin for Redmine
# Copyright (C) 2009-2012  Haruyuki Iida
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
require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class CodeReviewsControllerTest < Redmine::ControllerTest
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

    issues(:issues_003).update_column :status_id, 5  # close it
    @project = Project.find 'ecookbook'
    @request.session[:user_id] = 1
  end

  test "index should show open review list" do
    get :index, project_id: 'ecookbook'
    assert_response :success
    assert reviews = assigns(:reviews)
    assert_equal 2, reviews.size
  end

  test "index not show review list if module was not enabled." do
    get :index, project_id: 'onlinestore'
    assert_response 403
  end

  test "index should show all review list if show_closed is true" do
    get :index, project_id: 'ecookbook', show_closed: 'true'
    assert_response :success
    assert reviews = assigns(:reviews)
    assert_equal 3, reviews.size
  end

  test "new should render form" do
    xhr :get, :new, project_id: 'ecookbook', :action_type => 'diff', :rev => 5
    assert_response :success
    assert_template 'new'
  end

  context 'create' do
    should 'create new review' do
      assert_difference 'CodeReview.count' do
        xhr :post, :create, project_id: 'ecookbook', :review => {:line => 1, :change_id => 1,
          :comment => 'aaa', :subject => 'bbb'}, :action_type => 'diff'
      end
      assert_response :success
      assert_template 'create'

      xhr :get, :new, project_id: 'ecookbook', :action_type => 'diff', :rev => 5
      assert_response :success
      assert_template '_new_form'
    end

    should "create new review when changeset has related issue" do
      project = Project.find(1)
      change = Change.find(3)
      changeset = change.changeset
      issue = Issue.generate!(:project => project)
      changeset.issues << issue
      changeset.save
      assert_difference 'CodeReview.count' do
        xhr :post, :create, project_id: 'ecookbook', :review => {:line => 1, :change_id => 3,
          :comment => 'aaa', :subject => 'bbb'}, :action_type => 'diff'
      end
      assert_response :success
      assert_template 'create'

      CodeReviewProjectSetting.destroy_all
      assert_no_difference 'CodeReview.count' do
        xhr :post, :new, project_id: 'ecookbook', :review => {:line => 1, :change_id => 1,
          :comment => 'aaa', :subject => 'bbb'}, :action_type => 'diff'
      end
      assert_response 200
    end

    should "save safe_attributes" do
      project = Project.find(1)
      change = Change.find(3)
      changeset = change.changeset
      issue = Issue.generate!(:project => project)
      changeset.issues << issue
      changeset.save
      assert_difference 'CodeReview.count' do
        xhr :post, :create, project_id: 'ecookbook', :review => {:line => 10, :change_id => 3,
          :comment => 'aaa', :subject => 'bbb', :parent_id => 1, :status_id => 1}, :action_type => 'diff'
      end
      assert_response :success
      assert_template 'create'

      review = assigns :review
      assert_equal(1, review.project_id)
      assert_equal(3, review.change_id)
      assert_equal("bbb", review.subject)
      assert_equal(1, review.parent_id)
      assert_equal("aaa", review.comment)
      assert_equal(1, review.status_id)
    end

    should "create review for attachment" do
      project = Project.find(1)
      issue = Issue.generate!(:project => project)
      attachment = FactoryGirl.create(:attachment, container: issue)
      assert_difference 'CodeReview.count' do
        xhr :post, :create, project_id: 'ecookbook', :review => {:line => 1, :comment => 'aaa',
        :subject => 'bbb', :attachment_id => attachment.id}, :action_type => 'diff'
      end
      assert_response :success
      assert_template 'create'
    end
  end

  test "show should redirect" do
    get :show, project_id: 'ecookbook', id: 9
    assert_response 302
  end


  test "should destroy review and issue" do
    assert_difference 'CodeReview.count', -1 do
      assert_difference 'Issue.count', -1 do
        xhr :delete, :destroy, project_id: 'ecookbook', id: 11
        assert_response :success
      end
    end
  end

  context "reply" do
    should "create reply for review" do
      @request.session[:user_id] = 1

      review = CodeReview.find(9)
      assert_difference 'Journal.count' do
        xhr :post, :reply, project_id: 'ecookbook', id: 9,
          :reply => {:comment => 'aaa'}, :issue=> {:lock_version => review.issue.lock_version}
      end
      assert_response :success
      assert_template 'reply'
      assert_nil assigns(:error)
    end

    should "not create reply if anyone replied sametime" do
      @request.session[:user_id] = 1

      review = CodeReview.find(9)
      assert_no_difference 'Journal.count' do
        xhr :post, :reply, project_id: 'ecookbook', id: 9,
          :reply => {:comment => 'aaa'}, :issue=> {:lock_version => review.issue.lock_version + 1}
      end
      assert_response :success
      assert_template 'reply'
      assert_not_nil assigns(:error)
    end
  end

  def test_reply_lock_error
    @request.session[:user_id] = 1
    assert_no_difference 'Journal.count' do
      xhr :post, :reply, project_id: 'ecookbook', id: 9,
        :reply => {:comment => 'aaa'}, :issue=> {:lock_version => 1}
    end
    assert_response :success
    assert_template 'reply'
    assert assigns(:error)
  end

#  def test_close
#    @request.session[:user_id] = 1
#    review_id = 9
#    review = CodeReview.find(review_id)
#    review.reopen
#    review.save
#    assert !review.is_closed?
#    get :close, project_id: 'ecookbook', id: review_id
#    assert_response :success
#    assert_template '_show'
#    review = CodeReview.find(review_id)
#    assert review.is_closed?
#  end
#
#  def test_reopen
#    @request.session[:user_id] = 1
#    review = CodeReview.find(1)
#    review.close
#    review.save
#    assert review.is_closed?
#    get :reopen, project_id: 'ecookbook', id: 1
#    assert_response :success
#    assert_template '_show'
#    review = CodeReview.find(1)
#    assert !review.is_closed?
#  end

  def test_update
    review_id = 9
    review = CodeReview.find(review_id)
    assert_equal('Unable to print recipes', review.comment)
    xhr :patch, :update, project_id: 'ecookbook', id: review_id,
      :review => {:comment => 'bbb', :lock_version => review.lock_version},
      :issue => {:lock_version => review.issue.lock_version}
    assert_response :success
    review = CodeReview.find(review_id)
    assert_equal('bbb', review.comment)
  end

  def test_update_lock_error
    @request.session[:user_id] = 1
    review_id = 9
    review = CodeReview.find(review_id)
    assert_equal('Unable to print recipes', review.comment)
    xhr :patch, :update, project_id: 'ecookbook', id: review_id,
      :review => {:comment => 'bbb', :lock_version => review.lock_version},
      :issue => {:lock_version => 1}
    assert_response :success
    review = CodeReview.find(review_id)
    assert_equal('Unable to print recipes', review.comment)
    assert assigns(:error)
  end

  def test_forward_to_revision
    @request.session[:user_id] = 1
    #post :forward_to_revision, project_id: 'ecookbook', :path => '/test/some/path/in/the/repo'
  end

  def test_preview
    @request.session[:user_id] = 1
    review = {}
    review[:comment] = 'aaa'
    xhr :get, :preview, project_id: 'ecookbook', :review => review
    assert_response :success
  end

end
