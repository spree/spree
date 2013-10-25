module Spree
  class ProductsController < Spree::StoreController
    before_filter :load_product, :only => :show
    rescue_from ActiveRecord::RecordNotFound, :with => :render_404
    helper 'spree/taxons'

    respond_to :html

    def index
      @searcher = build_searcher(params)
      @products = @searcher.retrieve_products
    end

    def show
      return unless @product

      @variants = @product.variants_including_master.active(current_currency).includes([:option_values, :images])
      @product_properties = @product.product_properties.includes(:property)

      referer = request.env['HTTP_REFERER']
      if referer
        begin
          referer_path = URI.parse(request.env['HTTP_REFERER']).path
          # Fix for #2249
        rescue URI::InvalidURIError
          # Do nothing
        else
          if referer_path && referer_path.match(/\/t\/(.*)/)
            @taxon = Spree::Taxon.find_by_permalink($1)
          end
        end
      end
    end

    private
      def accurate_title
        @product ? @product.name : super
      end

      def load_product
        if try_spree_current_user.try(:has_spree_role?, "admin")
          @product = Product.find_by_permalink!(params[:id])
        else
          @product = Product.active(current_currency).find_by_permalink!(params[:id])
        end
      end
  end
end
