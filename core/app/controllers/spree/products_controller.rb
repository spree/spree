module Spree
  class ProductsController < BaseController
    before_filter :load_product, :only => :show
    before_filter :products_index, :only => [:index, :sitemap]
    rescue_from ActiveRecord::RecordNotFound, :with => :render_404
    helper 'spree/taxons'

    respond_to :html
    respond_to :xml, :only => :sitemap

    def index
      respond_with(@products)
    end

    def show
      return unless @product

      @variants = Variant.active.includes([:option_values, :images]).where(:product_id => @product.id)
      @product_properties = ProductProperty.includes(:property).where(:product_id => @product.id)

      referer_path = URI.parse(request.env['HTTP_REFERER']).path
      if referer_path && referer_path.match(/\/t\/(.*)/)
        @taxon = Taxon.find_by_permalink($1)
      end

      respond_with(@product)
    end

    def sitemap
      respond_with(@products)      
    end

    private

      def products_index
        @searcher = Config.searcher_class.new(params)
        @products = @searcher.retrieve_products
      end

      def accurate_title
        @product ? @product.name : super
      end

      def load_product
        @product = Product.active.find_by_permalink!(params[:id])
      end
  end
end
