class TaxonsController < Spree::BaseController
  resource_controller
  before_filter :load_data, :only => :show
  actions :show
  helper :products
  
  show.response do |wants|
    wants.html do 
      render :template => 'products/index.html.erb' if @taxon.children.empty?
    end
  end
  
  private
  def load_data
    @products ||= object.products.active.find(:all, :page => {:start => 1, :size => 10, :current => params[:p]}, :include => :images)
    @product_cols = 3
  end
  
  def object
    objects ||= end_of_association_chain.find_by_permalink(params[:id].join("/") + "/")
  end
 
end