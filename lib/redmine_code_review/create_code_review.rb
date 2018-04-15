module RedmineCodeReview
  class CreateCodeReview
    include RedmineCodeReview::FindSettings

    Result = ImmutableStruct.new(:review_created?, :review, :error)

    def initialize(project, review, user: User.current)
      @project = project
      @user = user
      @review = review
    end

    class CreationFailure < StandardError; end

    def call
      begin
        Issue.transaction do
          create_review
        end
      rescue CreationFailure
        return Result.new(review: @review, error: $!.message)
      end

      Result.new review: @review, review_created: true
    end

    def self.call(*_)
      new(*_).call
    end

    private

      def create_review
        @review.issue.save!

        if settings.auto_relation?
          if @review.changeset
            @review.changeset.issues.each do |issue|
              create_relation @review, issue
            end
          elsif @review.attachment and @review.attachment.container_type == 'Issue'
            create_relation @review, @review.attachment.container
          end
        end

        watchers = []
        @review.open_assignment_issues(@user.id).each do |issue|
          unless @review.issue.parent_id == issue.id
            create_relation @review, issue, type: IssueRelation::TYPE_RELATES
          end
          unless watchers.include?(issue.author)
            watchers << create_watcher(@review, issue.author)
          end
        end

        @review.save!

      rescue
        Rails.logger.error $!
        raise CreationFailure.new($!)
      end

      def create_relation(review, issue, type: settings.issue_relation_type)
        return unless issue.project == @project # TODO allow cross project relations if the Redmine instance allows it
        relation = IssueRelation.new
        relation.relation_type = type
        relation.issue_from_id = review.issue.id
        relation.issue_to_id = issue.id
        relation.save!
      rescue
        raise CreationFailure.new($!)
      end

      def create_watcher(review, user)
         Watcher.new.tap do |watcher|
           watcher.watchable = review.issue
           watcher.user = user
           watcher.save!
         end
      end

  end
end
