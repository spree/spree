module Spree
  module Fulfillments
    # Brings a canceled fulfillment back: the goods are going out after all, so
    # their units come off the shelf again and the fulfillment returns to
    # pending or ready depending on what the owning order can support.
    #
    # In the workflow tier for symmetry with Cancel — unstocking is a stock
    # movement, and a stock movement belongs in an explicit transaction rather
    # than a transition callback where a failure would leave the status changed
    # and the shelf wrong.
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
          step :unstock_units
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

      # Takes the units back off the shelf. Runs before the transition so a
      # variant that cannot be unstocked aborts while the fulfillment is still
      # canceled, rather than leaving it live with stock never taken.
      # Untracked variants are skipped — nothing counts them.
      def unstock_units
        fulfillment.manifest.each do |item|
          next unless item.variant.track_inventory?

          fulfillment.stock_location.unstock(item.variant, item.quantity, fulfillment)
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
