module Spree
  module Api
    module V3
      # Storefront access checks backed by Spree::Storefront::AccessPolicy —
      # the Store API's replacement for CanCanCan. Ownership scoping remains
      # the primary enforcement; these helpers cover the checks a scope cannot
      # express (guest-token access to a specific cart or order).
      module StorefrontAccess
        extend ActiveSupport::Concern

        protected

        def storefront_access_policy
          @storefront_access_policy ||= Spree.storefront_access_policy_class.new(
            user: current_user,
            store: current_store
          )
        end

        # @raise [Spree::Storefront::AccessDenied] when the caller can neither
        #   prove ownership nor (for carts/orders) present the guest token
        def authorize_storefront_read!(record, token: nil)
          return if storefront_access_policy.readable?(record, token: token)

          raise Spree::Storefront::AccessDenied
        end

        # @raise [Spree::Storefront::AccessDenied] when unreadable — or, for
        #   carts and orders, already completed
        def authorize_storefront_write!(record, token: nil)
          return if storefront_access_policy.writable?(record, token: token)

          raise Spree::Storefront::AccessDenied
        end
      end
    end
  end
end
