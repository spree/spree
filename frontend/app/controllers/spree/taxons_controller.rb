module Spree
  class TaxonsController < Spree::StoreController
    include Spree::FrontendHelper
    include Spree::CacheHelper
    helper 'spree/products'

    before_action :load_taxon

    respond_to :html

    def show
      if !http_cache_enabled? || stale?(etag: etag, last_modified: last_modified, public: true)
        load_products
      end
    end

    def product_carousel
      if !http_cache_enabled? || stale?(etag: carousel_etag, last_modified: last_modified, public: true)
        load_products
        if @products.reload.any?
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

    def etag
      [
        store_etag,
        @taxon,
        available_option_types_cache_key,
        filtering_params_cache_key
      ]
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
