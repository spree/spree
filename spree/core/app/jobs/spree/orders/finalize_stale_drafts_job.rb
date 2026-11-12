module Spree
  module Orders
    # Completion-recovery sweeper: retries FINALIZE for stale draft orders
    # whose payment coverage succeeded but whose finalize transaction never
    # committed (e.g. process crash after capture). Never auto-refunds —
    # persistent failures are surfaced to operators via logs/monitoring.
    #
    # A checkout that divided between sellers is found through its group
    # instead: the division moves the cart_id from the order to the group, so
    # an interrupted one leaves no draft carrying it. Its cart is still
    # unstamped, and replaying the cart's completion resumes the same group and
    # children rather than building new ones. A group with a canceled child is
    # left to its operator: placing its siblings would ship part of a purchase
    # someone already called off.
    class FinalizeStaleDraftsJob < Spree::BaseJob
      queue_as Spree.queues.default

      STALE_AFTER = 10.minutes

      def perform
        stale_drafts = Spree::Order.drafts.
                       where.not(cart_id: nil).
                       where(completed_at: nil).
                       where(created_at: ...STALE_AFTER.ago)

        each_store_of(stale_drafts) do |orders|
          orders.includes(:cart).find_each { |order| recover(order.cart, order.number) }
        end

        stale_groups = Spree::OrderGroup.
                       joins(:cart).merge(Spree::Cart.incomplete).
                       where(created_at: ...STALE_AFTER.ago).
                       where.not(id: Spree::Order.canceled.where.not(order_group_id: nil).select(:order_group_id)).
                       includes(:cart)

        each_store_of(stale_groups) do |groups|
          groups.find_each { |group| recover(group.cart, group.number) }
        end
      end

      private

      def recover(cart, number)
        return if cart.nil? || cart.completed?

        result = Spree::Dependencies.carts_complete_workflow.constantize.call(cart: cart)
        Rails.logger.error("[Spree] Completion recovery failed for #{number}: #{result.error&.value}") if result.failure?
      rescue StandardError => e
        Rails.logger.error("[Spree] Completion recovery raised for #{number}: #{e.message}")
      end
    end
  end
end
