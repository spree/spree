module Spree
  class StoreController < BaseController
    include Spree::Core::ControllerHelpers::Order

    include Spree::LocaleUrls
    include Spree::ThemeConcern
    include Spree::StorefrontHelper
    include Spree::PasswordProtected
    include Spree::WishlistHelper
    include Spree::AnalyticsHelper
    include Spree::IntegrationsHelper

    layout :choose_layout

    helper 'spree/base'
    helper 'spree/locale'
    helper 'spree/storefront_locale'
    helper 'spree/currency'
    helper 'spree/addresses'
    helper 'spree/wishlist'
    helper 'spree/integrations'

    helper_method :title
    helper_method :title=
    helper_method :accurate_title

    helper_method :current_taxon, :store_filter_names

    helper_method :permitted_products_params, :products_filters_params,
                  :storefront_products_scope, :storefront_products,
                  :default_products_sort, :default_products_finder_params,
                  :storefront_products_includes, :storefront_products_finder

    helper_method :stored_location

    before_action :redirect_to_default_locale
    before_action :render_404_if_store_not_exists
    rescue_from ActionController::InvalidAuthenticityToken, with: :invalid_authenticity_token

    def render_404_if_store_not_exists
      return if current_store.present?

      render 'errors/404', layout: 'application', status: :not_found
    end

    def current_taxon
      @current_taxon ||= (current_store.taxons.find_by(id: params[:taxon_id]) if params[:taxon_id].present?)
    end

    def store_filter_names
      @store_filter_names ||= Spree::OptionType.filterable.order(:position).pluck(:name)
    end

    def store_filter_names_hash
      filter_names = {}
      store_filter_names.each do |filter_name|
        filter_names[filter_name.to_sym] = []
      end
      filter_names
    end

    def permitted_products_params
      @permitted_products_params ||= params.permit(
        :locale,
        :currency,
        :q,
        :page,
        :per_page,
        :sort_by,
        filter: [
          :min_price,
          :max_price,
          :purchasable,
          :out_of_stock,
          {
            options: [store_filter_names_hash],
            taxon_ids: [],
            taxonomy_ids: [
              taxon_ids: []
            ]
          }
        ]
      )
    end

    def default_products_sort
      'manual'
    end

    def products_filters_params
      @products_filters_params ||= permitted_products_params[:filter]&.compact_blank || {}
    end

    protected

    def choose_layout
      if turbo_frame_request? && !current_theme_preview.present?
        'turbo_rails/frame'
      else
        'spree/storefront'
      end
    end

    # can be used in views as well as controllers.
    # e.g. <% self.title = 'This is a custom title for this view' %>
    attr_writer :title

    def title
      title_string = @title.present? ? @title : accurate_title
      if title_string.present?
        title_string
      else
        default_title
      end
    end

    def default_title
      @default_title ||= current_store.seo_title.presence || current_store.name
    end

    # this is a hook for subclasses to provide title
    def accurate_title
      @accurate_title ||= current_store.seo_title.presence || current_store.name
    end

    def storefront_products_finder
      @storefront_products_finder ||= Spree::Dependencies.products_finder.constantize
    end

    def storefront_products_scope
      @storefront_products_scope ||= current_store.products.active(current_currency)
    end

    def default_products_finder_params
      @default_products_finder_params ||= begin
        taxon = @taxon || current_taxon

        filter = permitted_products_params.fetch(:filter, {}).dup

        filter[:taxon_ids] ||= [taxon&.id.to_s].compact
        filter[:taxons] = filter[:taxon_ids].join(',')

        if filter.key?(:min_price) || filter.key?(:max_price)
          min_price = filter[:min_price].presence || 0
          max_price = filter[:max_price].presence || 'Infinity'

          filter[:price] = [min_price, max_price].compact.join(',')
        end

        permitted_products_params.merge(
          store: current_store,
          filter: filter,
          currency: current_currency
        )
      end
    end

    def storefront_products
      @storefront_products ||= begin
        finder_params = default_products_finder_params
        finder_params[:sort_by] ||= @taxon&.sort_order || 'manual'

        products_finder = storefront_products_finder
        products = products_finder.
                   new(scope: storefront_products_scope, params: finder_params).
                   execute.
                   includes(storefront_products_includes)

        default_per_page = Spree::Storefront::Config[:products_per_page]
        per_page = params[:per_page].present? ? params[:per_page].to_i : default_per_page
        page = params[:page].present? ? params[:page].to_i : 1

        products.page(page).per(per_page)
      end
    end

    def storefront_products_includes
      [
        :prices_including_master,
        :variant_images,
        :option_types,
        :option_values,
        { master: [:images, :prices, :stock_items, :stock_locations, { stock_items: :stock_location }],
          variants: [
            :images, :prices, :option_values, :stock_items, :stock_locations,
            { option_values: :option_type, stock_items: :stock_location }
          ],
          taxons: [:taxonomy],
          taggings: [:tag] }
      ]
    end

    def redirect_unauthorized_access
      if try_spree_current_user
        flash[:error] = Spree.t(:authorization_failure)
        redirect_to spree.forbidden_path
      else
        store_location
        if respond_to?(:spree_login_path)
          redirect_to spree_login_path
        else
          redirect_to spree.root_path
        end
      end
    end

    def redirect_back_or_default(default)
      Spree::Deprecation.warn('redirect_back_or_default is deprecated and will be removed in Spree 5.2. Please use redirect_back(fallback_location: default) instead.')
      redirect_back(fallback_location: default)
    end

    def require_user(return_to: nil, redirect_path: nil)
      return if try_spree_current_user

      store_location(return_to)

      respond_to do |format|
        format.html { redirect_to redirect_path || spree_login_path }
        format.turbo_stream { render turbo_stream: turbo_stream.slideover_open('slideover-account', 'account-pane') }
      end
    end

    def stored_location
      return unless defined?(after_sign_in_path_for)
      return unless defined?(Devise)

      path = after_sign_in_path_for(Devise.mappings.keys.first)

      store_location(path)

      path
    end

    def redirect_to_cart
      redirect_to spree.cart_path
    end

    def clear_order_token
      cookies.delete(:token)
    end

    def disable_sesion_tracking
      request.session_options[:skip] = true
    end

    def invalid_authenticity_token(exception)
      Rails.error.report(
        exception,
        context: { user_id: spree_current_user&.id },
        source: 'spree.storefront'
      )

      flash[:error] = Spree.t(:something_went_wrong)

      respond_to do |format|
        format.html { redirect_back_or_to root_path }
        format.turbo_stream { render turbo_stream: turbo_stream.update('flash', partial: 'spree/shared/flashes') }
      end
    end
  end
end
