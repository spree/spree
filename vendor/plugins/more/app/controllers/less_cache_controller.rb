class LessCacheController < ApplicationController
  caches_page :show, :if => proc { Less::More.page_cache? }
  write_inheritable_attribute('filter_chain', FilterChain.new)
  
  def show
    path_spec = params[:id]

    Less::More.compile(params[:id])
    
    if Less::More.exists?(params[:id])
      headers['Cache-Control'] = 'public; max-age=2592000' unless Less::More.page_cache? # Cache for a month.
      render :text => Less::More.generate(params[:id]), :content_type => "text/css"
    else
      render :nothing => true, :status => 404
    end
  end
  
  private
  
  # Don't log.
  def logger
    nil
  end
end