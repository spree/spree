module Spree
  class StoreController < Spree::BaseController
    include Spree::Core::ControllerHelpers::Order

    skip_before_action :set_current_order, only: :cart_link
    skip_before_action :verify_authenticity_token, only: :ensure_cart, raise: false

    def forbidden
      render 'spree/shared/forbidden', layout: Spree::Config[:layout], status: 403
    end

    def unauthorized
      render 'spree/shared/unauthorized', layout: Spree::Config[:layout], status: 401
    end

    def cart_link
      render partial: 'spree/shared/link_to_cart'
      fresh_when(simple_current_order)
    end

    def api_tokens
      render json: {
        order_token: current_order&.token,
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
  end
end
