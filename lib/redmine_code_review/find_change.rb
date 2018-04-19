module RedmineCodeReview
  module FindChange

    def find_change(changeset, path)
      if params[:change_id].present?
        if changeset
          changeset.filechanges.find params[:change_id]
        else
          Change.joins(:changeset)
                .where(changesets: { repository_id: repository.id })
                .find(params[:change_id])
        end
      elsif changeset and path.present? and path != '.'

        repository = changeset.repository
        url = repository.url
        root_url = repository.root_url
        if url.nil? or root_url.nil?
          fullpath = path
        else
          rootpath = url[root_url.length, url.length - root_url.length]
          if rootpath.blank?
            fullpath = path
          else
            fullpath = (rootpath + '/' + path).gsub(/[\/]+/, '/')
          end
        end

        changeset.filechanges.detect { |chg|
          chg.path == fullpath or
           "/#{chg.path}" == fullpath or
           chg.path == "/#{path}"
        }
      end
    end
    private :find_change

  end
end
