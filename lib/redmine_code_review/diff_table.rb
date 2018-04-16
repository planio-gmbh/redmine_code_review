module RedmineCodeReview

  # Reviews created on the 'single file diff' view always get a file index
  # (file_count in DB) of 0.
  #
  # This class builds a mapping from path to real file index which is used to
  # correctly position these reviews in the revision view (multiple file diff)
  # see update_diff_view.js.rb
  class DiffTable
    def initialize(repository, rev, rev_to)
      repository = repository
      rev = rev
      rev_to = rev_to

      diff = Redmine::UnifiedDiff.new(
        repository.diff('.', rev, rev_to),
        max_lines: Setting.diff_max_lines_displayed.to_i
      )

      @file_indizes = {}
      i = 0
      diff.each do |table_file|
        @file_indizes[table_file.file_name] = i
        i += 1
      end
    end

    def [](path)
      @file_indizes[path]
    end

  end

end
