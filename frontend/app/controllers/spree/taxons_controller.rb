module Spree
  class TaxonsController < Spree::StoreController
    helper 'spree/products'

    before_action :load_taxon, :load_products

    respond_to :html

    def show
    end

    def product_carousel
      if @products.any?
        render template: 'spree/taxons/product_carousel', layout: false
      else
        head :no_content
      end

      fresh_when etag: "product-carousel/#{@taxon.cache_key_with_version}", last_modified: @taxon.updated_at.utc, public: true
    end

    private

    def accurate_title
      @taxon.try(:seo_title) || super
    end

    def load_taxon
      @taxon = Spree::Taxon.friendly.find(params[:id])
    end

    def load_products
      @searcher = build_searcher(params.merge(taxon: @taxon.id, include_images: true))
      @products = @searcher.retrieve_products
    end
  end
end
