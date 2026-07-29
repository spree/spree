module Spree
  module Carts
    # Tiered cart-expiry reaper: guest carts after
    # +guest_cart_expiry_days+, customer carts after
    # +customer_cart_expiry_days+, empty carts after
    # +empty_cart_expiry_hours+ — measured on updated_at, batched. Carts
    # with money attached (authorized/pending payment sessions or payment
    # transactions) are never reaped.
    class ReapExpiredJob < Spree::BaseJob
      queue_as Spree.queues.default

      def perform
        reap(empty_scope.where(updated_at: ...Spree::Config[:empty_cart_expiry_hours].hours.ago))
        reap(guest_scope.where(updated_at: ...Spree::Config[:guest_cart_expiry_days].days.ago))
        reap(customer_scope.where(updated_at: ...Spree::Config[:customer_cart_expiry_days].days.ago))
      end

      private

      def base_scope
        Spree::Cart.incomplete.
          where.not(id: Spree::PaymentSession.where(status: %w[pending processing]).select(:cart_id)).
          where.not(id: Spree::Payment.where.not(state: Spree::Payment::INVALID_STATES).where.not(cart_id: nil).select(:cart_id))
      end

      def empty_scope
        base_scope.where.missing(:line_items)
      end

      def guest_scope
        base_scope.where(customer_id: nil)
      end

      def customer_scope
        base_scope.where.not(customer_id: nil)
      end

      def reap(scope)
        scope.in_batches(of: 200, &:destroy_all)
      end
    end
  end
end
