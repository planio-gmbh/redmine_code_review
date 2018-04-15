module RedmineCodeReview
  module FindSettings
    def settings
      @settings ||= CodeReviewProjectSetting.find_or_create(@project)
    end
    private :settings

  end
end
