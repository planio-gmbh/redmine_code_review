require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class CodeReviewsQueryTest < ActiveSupport::TestCase
  fixtures :projects, :code_reviews, :issues, :issue_statuses, :changes, :changesets

  setup do
    @project = Project.find 'ecookbook'
    issues(:issues_003).update_column :status_id, 5  # close it
  end

  test 'should count reviews' do
    q = RedmineCodeReview::CodeReviewsQuery.new(@project, 50, { })
    assert_equal 2, q.count

    q = RedmineCodeReview::CodeReviewsQuery.new(@project, 50,
                                                { show_closed: 'true' })
    assert_equal 3, q.count
  end

  test 'should retrieve reviews' do
    q = RedmineCodeReview::CodeReviewsQuery.new(@project, 50, { })
    assert_equal 2, q.scope.size

    q = RedmineCodeReview::CodeReviewsQuery.new(@project, 50,
                                                { show_closed: 'true' })
    assert_equal 3, q.scope.size
  end

end
