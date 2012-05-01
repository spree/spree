module Spree
  class ProductsController < BaseController
    HTTP_REFERER_REGEXP = /^https?:\/\/[^\/]+\/t\/([a-z0-9\-\/]+)$/
    rescue_from ActiveRecord::RecordNotFound, :with => :render_404
    helper 'spree/taxons'

    respond_to :html

    def index
      @searcher = Config.searcher_class.new(params)
      @products = @searcher.retrieve_products
      respond_with(@products)
    end

    def show
      begin
        @product = Spree::Product.active.find_by_permalink!(params[:id])
      rescue ActiveRecord::RecordNotFound => e
        # Allow admins to view any yet to be available products
        if current_user && current_user.has_role?('admin')
          @product = Spree::Product.find_by_permalink!(params[:id])
        else
          raise
        end
      end

      return unless @product

      @variants = Variant.active.includes([:option_values, :images]).where(:product_id => @product.id)
      @product_properties = ProductProperty.includes(:property).where(:product_id => @product.id)

      referer = request.env['HTTP_REFERER']

      if referer && referer.match(HTTP_REFERER_REGEXP)
        @taxon = Taxon.find_by_permalink($1)
      end

      respond_with(@product)
    end

    private
      def accurate_title
        @product ? @product.name : super
      end
  end
end
