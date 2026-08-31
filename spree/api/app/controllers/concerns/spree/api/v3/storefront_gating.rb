module Spree
  module Api
    module V3
      # Enforces channel-level storefront access gating on the Store API.
      # The posture is resolved from the request's channel
      # (+Spree::Channel#resolved_storefront_access+, with store fallback):
      #
      # - +login_required+    → 401 on every gated read for unauthenticated requests
      # - +prices_hidden+     → price fields serialized as +null+ for guests
      # - +approval_required+ → price fields serialized as +null+ unless the
      #   customer has standing over a policy-active company
      #   (docs/plans/6.0-b2b-company-self-registration.md)
      #
      # "Guest" means no authenticated customer (publishable key or guest cart
      # token without a customer JWT). Every nulled price travels with a
      # machine-readable +pricing_access+ reason code — +login_required+,
      # +company_required+, or a code the registered activation policy
      # supplies — so storefronts render "sign in" / "register your business"
      # from the code, never by interpreting bare nulls.
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
        # @param message_key [String] i18n key for the error message
        # @param default_message [String] fallback when the key is missing
        def render_authentication_required(message_key, default_message)
          render_error(
            code: ErrorHandler::ERROR_CODES[:authentication_required],
            message: Spree.t(message_key, default: default_message),
            status: :unauthorized
          )
        end

        # Whether this controller serves receipts — completed purchases and
        # the customer's own stored value, money already taken. The
        # +approval_required+ posture protects catalog prices, never a
        # buyer's record of what they were charged, so receipt surfaces opt
        # out of its per-customer gating. The shipped +prices_hidden+
        # guest semantics stay untouched. Override to return true.
        #
        # @return [Boolean]
        def renders_receipts?
          false
        end

        private

        def compute_pricing_access
          channel = current_channel
          return nil if channel.nil?

          if channel.storefront_prices_hidden?
            'login_required' if try_spree_current_user.blank?
          elsif channel.storefront_approval_required? && !renders_receipts?
            Spree.company_activation_policy.pricing_access_code(
              user: try_spree_current_user, store: current_store
            )
          end
        end

        def enforce_storefront_login_required!
          return if try_spree_current_user.present?
          return unless current_channel&.storefront_login_required?

          render_authentication_required('api.errors.storefront_login_required', 'Authentication required to access this store')
        end
      end
    end
  end
end
