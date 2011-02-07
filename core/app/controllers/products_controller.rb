class ProductsController < Spree::BaseController
  HTTP_REFERER_REGEXP = /^https?:\/\/[^\/]+\/t\/([a-z0-9\-\/]+)$/

  #prepend_before_filter :reject_unknown_object, :only => [:show]
  before_filter :load_data, :only => :show

  helper :taxons

  def show
  end

  def index
    @searcher = Spree::Config.searcher_class.new(params)
    @products = @searcher.retrieve_products
  end

  private

  def load_data
    @product = Product.where(:permalink => params[:id]).first
    @variants = Variant.active.where(:product_id => @product.id).includes([:option_values, :images])
    @product_properties = ProductProperty.where(:product_id => @product.id).includes(:property)
    @selected_variant = @variants.detect { |v| v.available? }

    referer = request.env['HTTP_REFERER']

    if referer  && referer.match(HTTP_REFERER_REGEXP)
      @taxon = Taxon.find_by_permalink($1)
    end
  end

  def accurate_title
    @product ? @product.name : nil
  end
end
