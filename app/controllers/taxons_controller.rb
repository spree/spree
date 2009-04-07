class TaxonsController < Spree::BaseController
  resource_controller
  before_filter :load_data, :only => :show
  actions :show
  helper :products
  
  private
  def load_data
    @search = object.products.active.new_search(params[:search])
    @search.per_page = Spree::Config[:products_per_page]
    @search.include = :images

    @product_cols = 3
    @products ||= @search.all
  end
  
  def object
    @object ||= end_of_association_chain.find_by_permalink(params[:id].join("/") + "/")
  end
 
end