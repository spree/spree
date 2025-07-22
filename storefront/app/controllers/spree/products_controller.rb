module Spree
  class ProductsController < Spree::StoreController
    helper 'spree/products'

    after_action :track_show, only: :show
    after_action :track_index, only: :index

    def index
      @current_page = current_theme.pages.find_by(type: 'Spree::Pages::ShopAll')
    end

    def show
      load_product
      redirect_if_legacy_path

      @current_page = current_theme.pages.product_details.first
    end

    def related
      @current_page = current_theme.pages.product_details.first
      section_scope = @current_page.sections.related_products
      @section = section_scope.find_by(id: params[:section_id]) || section_scope.first
      load_product
      # An interesting thing is that since we're querying the translations table (in the multi_search),
      # when using not default locale, our related products are different for different locales.
      @products = storefront_products_scope.where.not(id: @product.id).
                  multi_search(@product.name).includes(storefront_products_includes).
                  limit(@section.preferred_max_products_to_show)
    end

    private

    def accurate_title
      load_product if action_name == 'show' # we need this for ahoy analytics

      if @product
        @product.meta_title.blank? ? @product.name : @product.meta_title
      else
        params[:q].present? ? Spree.t(:search_results_for, query: params[:q]) : Spree.t(:shop_all)
      end
    end

    def load_product
      if params[:preview_id].present?
        possible_product = find_with_fallback_default_locale { current_store.products.friendly.find(params[:id]) }

        raise ActiveRecord::RecordNotFound if possible_product.id.to_s != params[:preview_id].to_s

        @product ||= possible_product
      else
        @product ||= find_with_fallback_default_locale { current_store.products.for_user(try_spree_current_user).friendly.find(params[:id]) }
      end

      options_hash = if params[:options].present?
                       params[:options].split(',').to_h do |option|
                         key, *value = option.split(':')
                         [key, value.join(':')]
                       end
                     else
                       {}
                     end

      variant_finder = Spree::Storefront::VariantFinder.new(
        product: @product,
        variant_id: params[:variant_id],
        current_currency: current_currency,
        options_hash: options_hash
      )

      @selected_variant, @variant_from_options =
        Rails.cache.fetch([@product.cache_key_with_version, 'variant-finder', current_currency, params[:variant_id], options_hash].compact) do
          variant_finder.find
        end
    end

    def redirect_if_legacy_path
      # If an old id or a numeric id was used to find the record,
      # we should do a 301 redirect that uses the current friendly id.
      if params[:id] != @product.friendly_id
        redirect_to spree.product_path(@product), status: :moved_permanently
      end
    end

    def track_show
      return if turbo_frame_request? || turbo_stream_request?
      return if params[:options].present? # we don't want to track product views for variants

      track_event('product_viewed', { product: @product })
    end

    def track_index
      return if turbo_frame_request? || turbo_stream_request?

      track_event('product_list_viewed', { taxon: @taxon })
    end
  end
end
