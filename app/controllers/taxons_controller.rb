class TaxonsController < Spree::BaseController
  prepend_before_filter :reject_unknown_object
  before_filter :load_data, :only => :show
  resource_controller
  actions :show
  helper :products

  private
  def load_data
    @search = object.products.active.search(params[:search])

    ## push into model?
    ## @search.per_page ||= Spree::Config[:products_per_page]
    
    @products ||= @search.paginate(:include  => [:images, {:variants => :images}],
                                   :per_page => Spree::Config[:products_per_page],
                                   :page     => params[:page])
    ## defunct?
    @product_cols = 3
  end

  def object
    @object ||= end_of_association_chain.find_by_permalink(params[:id].join("/") + "/")
  end
end
