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

        class_methods do
          # Opts a controller out of the +login_required+ gate. Use for endpoints
          # that must stay reachable before authentication — sign in / register,
          # password reset, and pre-login reference data (countries, currencies,
          # locales, markets, newsletter, tokenized digital downloads).
          def allow_guest_storefront_access!
            skip_before_action :enforce_storefront_login_required!, raise: false
          end
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

        # Renders a 401 with the shared +authentication_required+ error code.
        # @param message [String] translated error message
        # @param legacy_default [String, nil] deprecated: the two-argument form
        #   (key under +spree.+, fallback text) is removed in Spree 6.1
        def render_authentication_required(message, legacy_default = nil)
          unless legacy_default.nil?
            Spree::Deprecation.warn('render_authentication_required(key, default) is deprecated and will be removed in Spree 6.1. Pass the translated message instead.')
            message = I18n.t("spree.#{message}", default: legacy_default)
          end

          render_error(
            code: ErrorHandler::ERROR_CODES[:authentication_required],
            message: message,
            status: :unauthorized
          )
        end

        private

        def enforce_storefront_login_required!
          return if try_spree_current_user.present?
          return unless current_channel&.storefront_login_required?

          render_authentication_required(I18n.t('spree.api.errors.storefront_login_required'))
        end
      end
    end
  end
end
