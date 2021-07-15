module Spree
  class StoreController < ApplicationController
    include Spree::Core::ControllerHelpers::Auth
    include Spree::Core::ControllerHelpers::Common
    include Spree::Core::ControllerHelpers::Search
    include Spree::Core::ControllerHelpers::Store
    include Spree::Core::ControllerHelpers::StrongParameters
    include Spree::Core::ControllerHelpers::Locale
    include Spree::Core::ControllerHelpers::Currency
    include Spree::Core::ControllerHelpers::Order
    include Spree::LocaleUrls

    respond_to :html

    helper 'spree/base'
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
  end
end
