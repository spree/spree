module Spree
  module Fulfillments
    # Brings a canceled fulfillment back: the goods are going out after all, so
    # their units are promised again and the fulfillment returns to
    # unfulfilled.
    #
    # In the workflow tier for symmetry with Cancel — allocating is a stock
    # movement, and a stock movement belongs in an explicit transaction rather
    # than a transition callback where a failure would leave the status changed
    # and the ledger wrong.
    class Resume < Spree::Workflow
      hooks :validate, :after_resume

      # @param fulfillment [Spree::Fulfillment] the canceled fulfillment to resume
      # @return [Spree::ServiceModule::Result] the resumed fulfillment on success
      def perform(fulfillment:)
        super

        # Veto point — stock that has since been sold elsewhere, a closed
        # fulfilment window. Before anything is written.
        run_hooks :validate

        step :ensure_resumable

        ApplicationRecord.transaction do
          step :allocate_units
          step :mark_resumed
        end

        run_hooks :after_resume
        success(fulfillment.reload)
      end

      private

      def ensure_resumable
        return if fulfillment.can_resume?

        failure(fulfillment, Spree.t('fulfillments.errors.cannot_resume'))
      end

      # Reinstating a fulfillment re-promises its units. Nothing physical
      # moves — the goods are still on the shelf and only leave when the
      # parcel does. Runs before the transition so a failure leaves the
      # fulfillment canceled rather than live with no promise behind it.
      # Untracked variants are skipped — nothing counts them.
      def allocate_units
        fulfillment.manifest.each do |item|
          next unless item.variant.track_inventory?
          next unless item.quantity.positive?

          fulfillment.stock_location.allocate(item.variant, item.quantity, fulfillment)
        end
      end

      # Always back to unfulfilled. The old machine chose between pending and
      # ready here by consulting the order's payment state; that question is
      # asked at fulfill time now.
      def mark_resumed
        fulfillment.update!(status: 'unfulfilled')
        fulfillment.publish_fulfillment_resumed_event
      end
    end
  end
end
