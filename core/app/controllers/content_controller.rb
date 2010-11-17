class ContentController < Spree::BaseController

  before_filter :render_404, :if => :static_asset

  rescue_from ActionView::MissingTemplate, :with => :render_404
  caches_page :show, :index, :if => Proc.new { Spree::Config[:cache_static_content] }

  def show
    render params[:path]
  end

  def cvv
    render "cvv", :layout => false
  end

  private
  # Determines if the requested resource has a path similar to that of a static asset.  In this case do not go through the
  # overhead of trying to render a template or whatever.
  def static_asset
    params[:path] =~ /^\/([^.]+)$/
  end
end
