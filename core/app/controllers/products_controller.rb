class ProductsController < Spree::BaseController
  HTTP_REFERER_REGEXP = /^https?:\/\/[^\/]+\/t\/([a-z0-9\-\/]+)$/

  #prepend_before_filter :reject_unknown_object, :only => [:show]
  before_filter :load_data, :only => :show

  resource_controller
  helper :taxons
  actions :show, :index

  private

  def load_data
    load_object

    @variants = Variant.active.includes([:option_values, :images]).where(:product_id => @product.id)
    @product_properties = ProductProperty.includes(:property).where(:product_id => @product.id)
    @selected_variant = @variants.detect { |v| v.available? }

    referer = request.env['HTTP_REFERER']

    if referer  && referer.match(HTTP_REFERER_REGEXP)
      @taxon = Taxon.find_by_permalink($1)
    end
  end

  def collection
    @searcher = Spree::Config.searcher_class.new(params)
    @products = @searcher.retrieve_products
  end

  def accurate_title
    @product ? @product.name : nil
  end
end
