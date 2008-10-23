class ContentController < Spree::BaseController
  def show
    render :action => params[:path].join('/')
  end  
end
