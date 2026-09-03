module Spree
  module Fulfillments
    # Cancels a fulfillment: the goods are not going out, so the promise made
    # against their units is withdrawn and the carrier is told to stand down.
    #
    # In the workflow tier because cancelling talks to the outside world. The
    # provider call refunds a purchased label or cancels a 3PL pick — network
    # I/O that must not sit inside the database transaction holding the stock
    # movements, since a slow carrier would hold row locks open and a failed
    # call would roll back a release that already happened at the warehouse.
    # The release commits first; the provider is told afterwards.
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
          step :release_units
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

      # Withdraws the promise this fulfillment held. Nothing physical comes
      # back — the goods never left the shelf — so on-hand and backordered
      # units release the same way and the old backordered special case is
      # gone with the negative-on-hand representation it served.
      def release_units
        # Capped at what this fulfillment itself still holds: a fulfillment
        # created before typed movements holds no promise, and withdrawing one
        # it never made would take another order's units.
        outstanding = fulfillment.allocated_quantities

        fulfillment.manifest.each do |item|
          next unless item.variant.track_inventory?

          quantity = [item.quantity, outstanding[item.variant.id].to_i].min
          next unless quantity.positive?

          outstanding[item.variant.id] -= quantity
          stock_location.release(item.variant, quantity, fulfillment)
        end
      end

      def stock_location
        fulfillment.stock_location
      end

      def mark_canceled
        fulfillment.update!(status: 'canceled')
        fulfillment.publish_fulfillment_canceled_event
      end

      # Refunds every active label, then drops any non-label dispatch.
      def tell_provider_to_stand_down
        Spree::Fulfillments::StandDownProvider.new.call(fulfillment: fulfillment)
      end
    end
  end
end
