module Spree
  module Orders
    # Completion-recovery sweeper: retries FINALIZE for stale draft orders
    # whose payment coverage succeeded but whose finalize transaction never
    # committed (e.g. process crash after capture). Never auto-refunds —
    # persistent failures are surfaced to operators via logs/monitoring.
    class FinalizeStaleDraftsJob < Spree::BaseJob
      queue_as Spree.queues.default

      STALE_AFTER = 10.minutes

      def perform
        Spree::Order.drafts.
          where.not(cart_id: nil).
          where(completed_at: nil).
          where(created_at: ...STALE_AFTER.ago).
          find_each do |order|
            cart = order.cart
            next if cart.nil? || cart.completed?

            result = Spree::Dependencies.carts_complete_service.constantize.call(cart: cart)
            Rails.logger.error("[Spree] Completion recovery failed for order #{order.number}: #{result.error&.value}") if result.failure?
          rescue StandardError => e
            Rails.logger.error("[Spree] Completion recovery raised for order #{order.number}: #{e.message}")
          end
      end
    end
  end
end
