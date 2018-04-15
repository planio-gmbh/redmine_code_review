module RedmineCodeReview
  class CodeReviewsQuery
    def initialize(project, limit, params)
      @project = project
      @limit = limit
      @show_closed = params[:show_closed] == 'true'
    end

    def show_closed?
      @show_closed
    end

    def count
      base_scope.count
    end

    def scope
      base_scope.eager_load(change: [ :changeset ])
    end

    private

    def base_scope
      scope = CodeReview
                .where(project: @project)
                .joins(:issue)

      unless show_closed?
        scope = scope
          .joins(
            "inner join #{IssueStatus.table_name} on #{Issue.table_name}.status_id = #{IssueStatus.table_name}.id"
          )
          .where("#{IssueStatus.table_name}.is_closed = ? ", false)
      end

      scope
    end
#         .joins(<<-JOINS
# left join #{Change.table_name} on change_id = #{Change.table_name}.id
# left join #{Changeset.table_name} on #{Change.table_name}.changeset_id = #{Changeset.table_name}.id
# left join #{Issue.table_name} on issue_id = #{Issue.table_name}.id
# left join #{IssueStatus.table_name} on #{Issue.table_name}.status_id = #{IssueStatus.table_name}.id

  end
end
