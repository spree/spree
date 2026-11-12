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
    #
    # Continuable: the cursor is the store and the last record handled in it,
    # so a restart resumes where the sweep stopped.
    class FinalizeStaleDraftsJob < Spree::BaseJob
      include ActiveJob::Continuable

      queue_as Spree.queues.default

      STALE_AFTER = 10.minutes

      def perform
        step(:recover_drafts) { |step| sweep(step, stale_drafts) }
        step(:recover_groups) { |step| sweep(step, stale_groups) }
      end

      private

      def stale_drafts
        Spree::Order.drafts.where.not(cart_id: nil).where(completed_at: nil).where(created_at: ...STALE_AFTER.ago)
      end

      def stale_groups
        Spree::OrderGroup.joins(:cart).merge(Spree::Cart.incomplete).where(created_at: ...STALE_AFTER.ago)
      end

      def sweep(step, records)
        store_from, record_from = step.cursor
        stores = Spree::Store.with_deleted.where(id: records.select(:store_id))
        stores = stores.where(id: store_from..) if store_from

        stores.find_each do |store|
          Spree::Current.with_store(store) do
            in_store = records.where(store_id: store.id).includes(:cart)
            in_store = in_store.where(id: record_from..) if store.id == store_from && record_from

            in_store.find_each do |record|
              recover(record)
              step.set!([store.id, record.id + 1])
            end
          end
        end
      end

      def recover(record)
        cart = record.cart
        return if cart.nil? || cart.completed?
        # Asked here rather than in the query, so a cancellation made while the
        # sweep was running is still seen.
        return if record.is_a?(Spree::OrderGroup) && record.orders.canceled.exists?

        result = Spree::Dependencies.carts_complete_workflow.constantize.call(cart: cart)
        Rails.logger.error("[Spree] Completion recovery failed for #{record.number}: #{result.error&.value}") if result.failure?
      rescue StandardError => e
        Rails.logger.error("[Spree] Completion recovery raised for #{record.number}: #{e.message}")
      end
    end
  end
end
