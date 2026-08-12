module Spree
  module Fulfillments
    # Cancels a fulfillment: the goods are not going out, so their units go
    # back on the shelf and the carrier is told to stand down.
    #
    # In the workflow tier because cancelling talks to the outside world. The
    # provider call refunds a purchased label or cancels a 3PL pick — network
    # I/O that must not sit inside the database transaction holding the stock
    # movements, since a slow carrier would hold row locks open and a failed
    # call would roll back a restock that already happened at the warehouse.
    # Restocking commits first; the provider is told afterwards.
    class Cancel < Spree::Workflow
      hooks :validate, :after_cancel

      # @param fulfillment [Spree::Fulfillment] the fulfillment to cancel
      # @param notify_provider [Boolean] whether to tell the carrier here. Pass
      #   false when the caller already holds a transaction and will batch the
      #   provider calls into its own external step — Spree::Orders::Cancel
      #   cancels every fulfillment on the order that way. A nested
      #   external_step would raise, correctly, since carrier I/O must never sit
      #   inside a transaction.
      # @return [Spree::ServiceModule::Result] the canceled fulfillment on success
      def perform(fulfillment:, notify_provider: true)
        super

        # Veto point — a 3PL that has already picked the order, a label that
        # cannot be refunded. Before anything is written.
        run_hooks :validate

        step :ensure_cancelable

        ApplicationRecord.transaction do
          step :restock_units
          step :mark_canceled
        end

        external_step :tell_provider_to_stand_down if notify_provider

        run_hooks :after_cancel
        success(fulfillment.reload)
      end

      private

      def ensure_cancelable
        return if fulfillment.can_cancel?

        failure(fulfillment, Spree.t('fulfillments.errors.cannot_cancel'))
      end

      # Puts every unit back on the shelf. On-hand and backordered units go
      # back by different routes: an on-hand unit returns real stock, while a
      # backordered one only cancels the promise made against stock that never
      # arrived, so restocking it as on-hand would invent inventory.
      def restock_units
        fulfillment.manifest.each do |item|
          on_hand = item.states['on_hand'].to_i
          backordered = item.states['backordered'].to_i

          stock_location.restock(item.variant, on_hand, fulfillment) if on_hand.positive?
          stock_location.restock_backordered(item.variant, backordered) if backordered.positive?
        end
      end

      def stock_location
        fulfillment.stock_location
      end

      def mark_canceled
        fulfillment.update!(status: 'canceled')
        fulfillment.publish_fulfillment_canceled_event
      end

      def tell_provider_to_stand_down
        fulfillment.provider.cancel_fulfillment(fulfillment)
      end
    end
  end
end
