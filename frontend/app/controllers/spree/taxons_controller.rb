module Spree
  class TaxonsController < Spree::StoreController
    helper 'spree/products'

    before_action :load_taxon, :load_products

    respond_to :html

    def show
    end

    def product_carousel
      if stale?(etag: carousel_etag, last_modified: last_modified, public: true)
        load_products
        if @products.any?
          render template: 'spree/taxons/product_carousel', layout: false
        else
          head :no_content
        end
      end
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

    def carousel_etag
      [
        store_etag,
        @taxon
      ]
    end

    def last_modified
      @taxon.updated_at&.utc
    end
  end
end
