module RedmineCodeReview
  module FindRepository

    def repository
      @repository ||= begin
        # FIXME swith to exclusively using repository.id and find()
        repository = if params[:repository_id].present?
          @project.repositories.find_by_identifier_param(params[:repository_id])
        else
          @project.repository
        end
        repository || raise(ActiveRecord::RecordNotFound)
      end
    end

  end
end
