module Spree
  module Storefront
    # Storefront record access in one swappable object. The Store API never
    # consults CanCanCan — customer authorization is ownership, enforced by
    # scope-fetching, with this policy holding the two checks that cannot be a
    # scope (cart/order access proven by JWT ownership OR a guest token) and
    # the ownership scopes worth widening.
    #
    # This class is the storefront's extension seam: replace it via
    # `Spree::Dependencies.storefront_access_policy_class` when access must
    # widen beyond the owner — e.g. B2B company accounts where an approver
    # sees every purchase placed by their company location
    # (docs/plans/6.1-channels-catalogs-b2b.md). Action vetoes (approval
    # required, spending limits) do not belong here — they are checkout
    # workflow `validate` hooks.
    class AccessPolicy
      # @return [Object, nil] the authenticated customer, or nil for guests
      attr_reader :user

      # @return [Spree::Store]
      attr_reader :store

      def initialize(user:, store:)
        @user = user
        @store = store
      end

      # Whether the caller may read a cart or order: its owner (by JWT) or the
      # bearer of its guest token.
      #
      # @param purchase [Spree::Cart, Spree::Order]
      # @param token [String, nil] the X-Spree-Token header value
      # @return [Boolean]
      def purchase_readable?(purchase, token: nil)
        purchase_owner?(purchase) || purchase_token_match?(purchase, token)
      end

      # Whether the caller may mutate a cart or order — readable and not yet
      # completed.
      #
      # @param purchase [Spree::Cart, Spree::Order]
      # @param token [String, nil]
      # @return [Boolean]
      def purchase_writable?(purchase, token: nil)
        !purchase.completed? && purchase_readable?(purchase, token: token)
      end

      # The completed orders the caller may list and look up. Owner-only by
      # default; the guest-token branch serves order-confirmation lookups.
      #
      # @param base [ActiveRecord::Relation] pre-scoped orders (store, complete)
      # @param token [String, nil]
      # @return [ActiveRecord::Relation]
      def orders_scope(base, token: nil)
        if user.present?
          base.where(customer: user)
        elsif token.present?
          base.where(token: token)
        else
          base.none
        end
      end

      protected

      def purchase_owner?(purchase)
        user.present? && purchase.customer == user
      end

      def purchase_token_match?(purchase, token)
        purchase.token.present? && token == purchase.token
      end
    end
  end
end
