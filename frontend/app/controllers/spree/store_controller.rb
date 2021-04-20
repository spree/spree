module Spree
  class StoreController < Spree::BaseController
    include Spree::Core::ControllerHelpers::Order
    include Spree::LocaleUrls

    helper 'spree/locale'
    helper 'spree/currency'

    skip_before_action :verify_authenticity_token, only: :ensure_cart, raise: false

    before_action :redirect_to_default_locale
    before_action :load_menus

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

    def load_menus
      @menus = Spree::Menu.by_store(current_store)
    end

    def find_menu_by_unique_code(code)
      menu = @menus.by_unique_code(code)

      return if menu.nil?

      menu[0]
    end
    helper_method :find_menu_by_unique_code

    def menu_items_for_menu_with_unique_code(code)
      menu = @menus.by_unique_code(code)[0] || nil

      return if menu.nil?

      menu.menu_items.order(:lft)
    end
    helper_method :menu_items_for_menu_with_unique_code

    protected

    def config_locale
      Spree::Frontend::Config[:locale]
    end

    def store_etag
      [
        current_store,
        current_currency,
        I18n.locale
      ]
    end

    def store_last_modified
      (current_store.updated_at || Time.current).utc
    end
  end
end
