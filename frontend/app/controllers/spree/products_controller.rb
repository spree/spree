module Spree
  class ProductsController < Spree::StoreController
    include Spree::ProductsHelper
    include Spree::FrontendHelper

    before_action :load_product, only: [:show, :related]
    before_action :load_taxon, only: :index

    respond_to :html

    def index
      @searcher = build_searcher(params.merge(include_images: true, current_store_id: current_store.id))
      @products = @searcher.retrieve_products

      last_modified = @products.maximum(:updated_at)&.utc if @products.respond_to?(:maximum)

      etag = [
        store_etag,
        last_modified&.to_i,
        available_option_types_cache_key,
        filtering_params_cache_key
      ]

      fresh_when etag: etag, last_modified: last_modified, public: true
    end

    def show
      redirect_if_legacy_path

      @taxon = params[:taxon_id].present? ? Spree::Taxon.find(params[:taxon_id]) : @product.taxons.first

      if stale?(etag: product_etag, last_modified: @product.updated_at.utc, public: true)
        @product_summary = Spree::ProductSummaryPresenter.new(@product).call
        @product_properties = @product.product_properties.includes(:property)
        @product_price = @product.price_in(current_currency).amount
        load_variants
        @product_images = product_images(@product, @variants)
      end
    end

    def related
      @related_products = related_products

      if @related_products.any?
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
      @products = if try_spree_current_user.try(:has_spree_role?, 'admin')
                    Product.with_deleted
                  else
                    Product.active(current_currency)
                  end

      @product = @products.includes(:master).
                 friendly.
                 find(params[:id])
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

    def product_etag
      [
        store_etag,
        @product,
        @taxon,
        @product.possible_promotion_ids,
        @product.possible_promotions.maximum(:updated_at),
      ]
    end
  end
end
