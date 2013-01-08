module Spree
  class ContentController < Spree::StoreController
    # Don't serve local files or static assets
    before_filter { render_404 if params[:path] =~ /(\.|\\)/ }
    after_filter :fire_visited_path, :only => :show
    after_filter :fire_visited_action, :except => :show

    rescue_from ActionView::MissingTemplate, :with => :render_404
    caches_page :show, :index, :if => Proc.new { Spree::Config[:cache_static_content] }

    respond_to :html

    def show
      render :action => params[:path]
    end

    def cvv
      render :layout => false
    end

    private

    def fire_visited_path
      fire_event('spree.content.visited', :path => "content/#{params[:path]}")
    end

    def fire_visited_action
      fire_event('spree.content.visited', :path => "content/#{params[:action]}")
    end
  end
end
