class CodeReviewViewsController < ApplicationController
  include RedmineCodeReview::FindRepository

  before_filter :find_project_by_project_id, :authorize

  def update_revisions_view
    changeset_ids = params[:changeset_ids].to_s.split(',')
    changeset_ids.reject!(&:blank?)
    @changesets = repository.changesets.find changeset_ids
    render partial: 'update_revisions'
  end


  def update_diff_view
    find_review_if_present

    @repository = repository
    @review = CodeReview.new

    @rev_to = params[:rev_to].presence
    @path   = params[:path].presence

    @paths = []
    @paths << @path if @path

    @action_type = params[:action_type]

    if id = params[:changeset_id].presence
      @changeset = repository.changesets.find id
      @rev = @changeset.revision
    else
      # TODO remove, should be unused except maybe in tests
      @rev    = params[:rev].presence
      @changeset = repository.find_changeset_by_name(@rev)
    end

    # FIXME was the empty loop good for anything?
    #if @paths.empty?
    #  changeset.filechanges.each{|chg|
    #  }
    #end

    url = repository.url
    root_url = repository.root_url
    if url.nil? or root_url.nil?
      fullpath = @path
    else
      rootpath = url[root_url.length, url.length - root_url.length]
      if rootpath.blank?
        fullpath = @path
      else
        fullpath = (rootpath + '/' + @path).gsub(/[\/]+/, '/')
      end
    end

    @change = nil
    @reviews = CodeReview.where(project: @project, rev: @rev)

    if @path
      @change = @changeset.filechanges.detect { |chg|
        chg.path == fullpath or
         "/#{chg.path}" == fullpath or
         chg.path == "/#{@path}"
      }
      @reviews = @reviews.where file_path: @path
    end

    # FIXME why here? That should have been set at creation time
    @review.change_id = @change.id if @change
  end


  def update_attachment_view
    find_review_if_present

    @attachment = Attachment.find params[:attachment_id]
    @attachment_id = @attachment.id
    @review = CodeReview.new

    @reviews = CodeReview.where(project: @project, attachment: @attachment)

    render 'update_diff_view'
  end

  private

  def find_review_if_present
    if id = params[:review_id].presence
      @show_review = CodeReview.where(project: @project).find id
    end
  end
end

