module Spree
  class ProductsController < Spree::StoreController
    include Spree::ProductsHelper
    include Spree::FrontendHelper
    include Spree::CacheHelper

    before_action :load_product, only: [:show, :related]
    before_action :load_taxon, only: :index

    respond_to :html

    def index
      @searcher = build_searcher(params.merge(include_images: true, current_store_id: current_store.id))
      @products = @searcher.retrieve_products

      if http_cache_enabled?
        fresh_when etag: etag_index, last_modified: last_modified_index, public: true
      end
    end

    def show
      redirect_if_legacy_path

      @taxon = params[:taxon_id].present? ? Spree::Taxon.find_by(id: params[:taxon_id]) : nil
      @taxon = @product.taxons.first unless @taxon.present?

      if !http_cache_enabled? || stale?(etag: etag_show, last_modified: last_modified_show, public: true)
        @product_summary = Spree::ProductSummaryPresenter.new(@product).call
        @product_properties = @product.product_properties.includes(:property)
        @product_price = @product.price_in(current_currency).amount
        load_variants
        @product_images = product_images(@product, @variants)
      end
    end

    def related
      if product_relation_types.any?
        render template: 'spree/products/related', layout: false
      else
        head :no_content
      end
    end

    private

    def accurate_title
      if @product
        @product.meta_title.blank? ? @product.name : @product.meta_title
      else
        super
      end
    end

    def load_product
      @product = Product.for_user(try_spree_current_user).friendly.find(params[:id])
    end

    def load_taxon
      @taxon = Spree::Taxon.find(params[:taxon]) if params[:taxon].present?
    end

    def load_variants
      @variants = @product.
                  variants_including_master.
                  spree_base_scopes.
                  active(current_currency).
                  includes(
                    :default_price,
                    option_values: [:option_value_variants],
                    images: { attachment_attachment: :blob }
                  )
    end

    def redirect_if_legacy_path
      # If an old id or a numeric id was used to find the record,
      # we should do a 301 redirect that uses the current friendly id.
      if params[:id] != @product.friendly_id
        params[:id] = @product.friendly_id
        params.permit!
        redirect_to url_for(params), status: :moved_permanently
      end
    end

    def etag_index
      [
        store_etag,
        last_modified_index,
        available_option_types_cache_key,
        filtering_params_cache_key
      ]
    end

    def etag_show
      [
        store_etag,
        @product,
        @taxon,
        @product.possible_promotion_ids,
        @product.possible_promotions.maximum(:updated_at),
      ]
    end

    alias product_etag etag_show

    def last_modified_index
      products_last_modified      = @products.maximum(:updated_at)&.utc if @products.respond_to?(:maximum)
      current_store_last_modified = current_store.updated_at.utc

      [products_last_modified, current_store_last_modified].compact.max
    end

    def last_modified_show
      product_last_modified       = @product.updated_at.utc
      current_store_last_modified = current_store.updated_at.utc

      [product_last_modified, current_store_last_modified].compact.max
    end
  end
end
