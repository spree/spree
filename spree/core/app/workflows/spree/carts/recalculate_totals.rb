module Spree
  module Carts
    # Money recalculation — item counts, money totals (with the
    # typed-adjustment two-pass), one update_columns persist. Money ONLY:
    # payment_status/fulfillment_status are written exclusively by
    # Spree::Orders::RecomputeStatuses, triggered from
    # Spree::OrderStatusSubscriber on payment/refund/fulfillment/return
    # events; completed-order fulfillment repricing belongs to the explicit
    # post-placement edit path, never to a totals refresh.
    #
    # Granular math stays on the calculator objects (Spree::OrderUpdater /
    # Spree::CartUpdater, resolved polymorphically via the model's #updater);
    # this workflow owns the sequence. Callers use it (or the model's
    # #recalculate_totals! convenience) — never the calculator's #update,
    # which is deprecated.
    class RecalculateTotals < Spree::Workflow
      # @param cart [Spree::Cart, Spree::Order]
      def perform(cart:)
        super

        step :reset_association_caches
        step :update_item_count
        step :update_money_totals
        step :persist_totals

        success(cart)
      end

      private

      # An earlier recalculation on this instance may have loaded the
      # associations mid-mutation.
      def reset_association_caches
        return unless cart.persisted?

        cart.association(:line_items).reset
        cart.association(:fulfillments).reset
      end

      def update_item_count
        cart.updater.update_item_count
      end

      def update_money_totals
        cart.updater.update_totals
      end

      def persist_totals
        cart.updater.persist_totals
      end
    end
  end
end
