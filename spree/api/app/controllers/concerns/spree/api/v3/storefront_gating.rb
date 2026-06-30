module Spree
  module Api
    module V3
      # Enforces channel-level storefront access gating on the Store API.
      # The posture is resolved from the request's channel
      # (+Spree::Channel#resolved_storefront_access+, with store fallback):
      #
      # - +login_required+ → 401 on every gated read for unauthenticated requests
      # - +prices_hidden+  → price fields serialized as +null+ for guests
      #
      # "Guest" means no authenticated customer (publishable key or guest cart
      # token without a customer JWT). Logged-in customers are never gated.
      module StorefrontGating
        extend ActiveSupport::Concern

        included do
          before_action :enforce_storefront_login_required!
        end

        protected

        # @return [Boolean] whether prices must be hidden from this request.
        def hide_prices?
          try_spree_current_user.blank? && !!current_channel&.storefront_prices_hidden?
        end

        # Injects the price-hiding flag so the shared +price_for+/+price_in+
        # serializer helpers null prices for gated guests.
        def serializer_params
          super.merge(hide_prices: hide_prices?)
        end

        # @param order [Spree::Order]
        # @return [Boolean] true when the order cannot be completed because the
        #   channel forbids guest checkout and the order has no registered user.
        def guest_checkout_blocked?(order)
          return false if order.user.present?

          channel = order.channel || current_channel
          channel.present? && !channel.resolved_guest_checkout
        end

        private

        def enforce_storefront_login_required!
          return if try_spree_current_user.present?
          return unless current_channel&.storefront_login_required?

          render_error(
            code: ErrorHandler::ERROR_CODES[:authentication_required],
            message: Spree.t('api.errors.storefront_login_required', default: 'Authentication required to access this store'),
            status: :unauthorized
          )
        end
      end
    end
  end
end
