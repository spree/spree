module Spree
  class StoreController < Spree::BaseController
    include Spree::Core::ControllerHelpers::Order
    include Spree::LocaleUrls

    helper 'spree/locale'
    helper 'spree/currency'

    skip_before_action :verify_authenticity_token, only: :ensure_cart, raise: false

    before_action :redirect_to_default_locale

    def account_link
      render partial: 'spree/shared/link_to_account'
      fresh_when(etag: [try_spree_current_user, I18n.locale])
    end

    def cart_link
      render partial: 'spree/shared/link_to_cart'
      fresh_when(etag: [simple_current_order, I18n.locale])
    end

    def api_tokens
      render json: {
        order_token: simple_current_order&.token,
        oauth_token: current_oauth_token&.token
      }
    end

    def ensure_cart
      render json: current_order(create_order_if_necessary: true) # force creation of order if doesn't exists
    end

    # Find a menu by its unique_code
    # this method will only return a menu if it is
    # available for use in the current store.
    def menu(unique_code)
      menu = available_menus.by_unique_code(unique_code)
      menu[0]
    end
    helper_method :menu

    # Returns the root for the menu by unique_code.
    # You can use .children to retrieve the top level of menu items,
    # or .descendants to retrieve all menu items.
    def root_item_for_menu(unique_code)
      if menu(unique_code).present?
        menu(unique_code).root
      end
    end
    helper_method :root_item_for_menu

    # Returns only the top level items for the menu by unique_code
    def top_level_items_for_menu(unique_code)
      if menu(unique_code).present?
        menu(unique_code).root.children
      end
    end
    helper_method :top_level_items_for_menu

    protected

    def config_locale
      Spree::Frontend::Config[:locale]
    end

    def store_etag
      [
        current_store,
        current_currency,
        I18n.locale,
        try_spree_current_user.present?,
        try_spree_current_user.try(:has_spree_role?, 'admin')
      ].compact
    end

    def store_last_modified
      (current_store.updated_at || Time.current).utc
    end
  end
end
