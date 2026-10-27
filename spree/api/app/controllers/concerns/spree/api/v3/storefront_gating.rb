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

          class_attribute :storefront_renders_receipts, instance_writer: false, default: false
        end

        class_methods do
          # Opts a controller out of the +login_required+ gate. Use for endpoints
          # that must stay reachable before authentication — sign in / register,
          # password reset, and pre-login reference data (countries, currencies,
          # locales, markets, newsletter, tokenized digital downloads).
          def allow_guest_storefront_access!
            skip_before_action :enforce_storefront_login_required!, raise: false
          end

          # Opts a controller out of the +approval_required+ price gate. Use
          # for receipt surfaces — completed purchases and the customer's own
          # stored value, money already taken. The posture protects catalog
          # prices, never a buyer's record of what they were charged; the
          # shipped +prices_hidden+ guest semantics stay untouched.
          #
          # For a controller that renders receipts on only some of its paths,
          # call {#rendering_receipt!} on those instead.
          def renders_receipts!
            self.storefront_renders_receipts = true
          end
        end

        protected

        # Declares that this particular response is a receipt, for a
        # controller whose other paths are not — the cart endpoints, which
        # answer with a completed order once checkout has succeeded. Must run
        # before the serializer params are read.
        def rendering_receipt!
          @rendering_receipt = true
          remove_instance_variable(:@pricing_access) if defined?(@pricing_access)
        end

        # @return [Boolean] whether prices must be hidden from this request.
        def hide_prices?
          pricing_access.present?
        end

        # Why prices are withheld from this request — nil when they are
        # visible. Computed once per request; rendered by the serializers
        # beside every nulled price.
        #
        # @return [String, nil]
        def pricing_access
          return @pricing_access if defined?(@pricing_access)

          @pricing_access = compute_pricing_access
        end

        # Injects the price-hiding flag so the shared +price_for+/+price_in+
        # serializer helpers null prices for gated requests, and the reason
        # code the priced payloads render beside the nulls.
        def serializer_params
          super.merge(hide_prices: hide_prices?, pricing_access: pricing_access)
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

        def compute_pricing_access
          channel = current_channel
          return nil if channel.nil?

          if channel.storefront_prices_hidden?
            'login_required' if try_spree_current_user.blank?
          elsif channel.storefront_approval_required? && !receipt_response?
            Spree.company_activation_policy.pricing_access_code(
              user: try_spree_current_user, store: current_store
            )
          end
        end

        # Whether this response is a buyer's record of money already taken,
        # declared for the whole controller or just for this path.
        def receipt_response?
          storefront_renders_receipts || @rendering_receipt.present?
        end

        def enforce_storefront_login_required!
          return if try_spree_current_user.present?
          return unless current_channel&.storefront_login_required?

          render_authentication_required(I18n.t('spree.api.errors.storefront_login_required'))
        end
      end
    end
  end
end
