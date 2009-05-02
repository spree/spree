class ContentController < Spree::BaseController
  rescue_from ActionView::MissingTemplate, :with => :render_404

  def show
    render :action => params[:path].join('/')
  end
  
  def cvv
    render "cvv", :layout => false
  end  

  protected
  def render_404(exception)
    respond_to do |type|
      type.html { render :file => "#{RAILS_ROOT}/public/404.html", :status => "404 Not Found" }
      type.all  { render :nothing => true, :status => "404 Not Found" }
    end
  end
end
