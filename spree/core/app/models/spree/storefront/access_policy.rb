module Spree
  module Storefront
    # Storefront record access in one swappable object. The Store API never
    # consults CanCanCan — customer authorization is ownership, and this
    # policy is where ownership is decided, for any resource:
    #
    # - `readable?` / `writable?` answer per-record access,
    # - `scope` narrows a relation to what the caller may list.
    #
    # The default answer is "the caller owns the record" (guests own
    # nothing); carts and orders specialize it with guest-token access and a
    # completed?-guard on writes. New resources — core or extension — get the
    # ownership default with no wiring.
    #
    # This class is the storefront's extension seam: replace it via
    # `Spree::Dependencies.storefront_access_policy_class` when access must
    # widen beyond the owner — e.g. B2B company accounts where an approver
    # sees every purchase or shared wishlist of their company location
    # (docs/plans/6.1-channels-catalogs-b2b.md). Override the entry points
    # and fall through to `super`:
    #
    #   class Enterprise::CompanyAccessPolicy < Spree::Storefront::AccessPolicy
    #     def scope(base, token: nil)
    #       return base.where(company_location_id: approver_location_ids) if
    #         base.klass <= Spree::Order && approver?
    #
    #       super
    #     end
    #   end
    #
    # Two things deliberately stay out of the policy: action vetoes (approval
    # required, spending limits) are checkout workflow `validate` hooks, and
    # the `/customers/me/*` endpoints stay owner-scoped by definition —
    # company-wide surfaces are their own endpoints built on this policy.
    class AccessPolicy
      # @return [Object, nil] the authenticated customer, or nil for guests
      attr_reader :user

      # @return [Spree::Store]
      attr_reader :store

      def initialize(user:, store:)
        @user = user
        @store = store
      end

      # Whether the caller may read a record: its owner by default; for carts
      # and orders, the owner (by JWT) or the bearer of the guest token.
      #
      # @param record [ActiveRecord::Base]
      # @param token [String, nil] the X-Spree-Token header value
      # @return [Boolean]
      def readable?(record, token: nil)
        return purchase_readable?(record, token: token) if purchase?(record)

        owned?(record)
      end

      # Whether the caller may mutate a record. Same as +readable?+ by
      # default; carts and orders additionally refuse once completed.
      #
      # @param record [ActiveRecord::Base]
      # @param token [String, nil]
      # @return [Boolean]
      def writable?(record, token: nil)
        return purchase_writable?(record, token: token) if purchase?(record)

        owned?(record)
      end

      # Narrows a relation to the records the caller may list: the caller's
      # own by default; for orders, the guest-token branch serves
      # order-confirmation lookups.
      #
      # @param base [ActiveRecord::Relation] pre-scoped by the controller
      #   (store, completeness, channel — every axis but ownership)
      # @param token [String, nil]
      # @return [ActiveRecord::Relation]
      def scope(base, token: nil)
        return purchases_scope(base, token: token) if purchase_class?(base.klass)

        owned_scope(base)
      end

      protected

      # --- carts and orders: token semantics ---

      def purchase_readable?(purchase, token:)
        purchase_owner?(purchase) || purchase_token_match?(purchase, token)
      end

      def purchase_writable?(purchase, token:)
        !purchase.completed? && purchase_readable?(purchase, token: token)
      end

      def purchases_scope(base, token:)
        if user.present?
          base.where(customer: user)
        elsif token.present?
          base.where(token: token)
        else
          base.none
        end
      end

      def purchase_owner?(purchase)
        user.present? && purchase.customer == user
      end

      def purchase_token_match?(purchase, token)
        purchase.token.present? && token == purchase.token
      end

      def purchase?(record)
        record.is_a?(Spree::Cart) || record.is_a?(Spree::Order)
      end

      def purchase_class?(klass)
        klass <= Spree::Cart || klass <= Spree::Order
      end

      # --- everything else: ownership ---

      # Ownership keys on `customer_id`, the canonical column since the
      # user_id -> customer_id rename (a record with no such column is owned by
      # no one, so the check fails closed). Deliberately not the deprecated
      # `user_id` alias, which disappears with the shim in 6.1.
      def owned?(record)
        user.present? && record.respond_to?(:customer_id) && record.customer_id == user.id
      end

      def owned_scope(base)
        return base.none if user.blank?

        base.where(customer_id: user.id)
      end
    end
  end
end
