class TaxonsController < Spree::BaseController
  resource_controller
  before_filter :load_data, :only => :show
  actions :show
  helper :products
  
  show.response do |wants|
    wants.html { render :template => 'products/index.html.erb' }
  end
  
  private
  def load_data
    @products ||= object.products.available.find(:all, :page => {:start => 1, :size => 10, :current => params[:p]}, :include => :images)
    @product_cols = 3
  end
  
end