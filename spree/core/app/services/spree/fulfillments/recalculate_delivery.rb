module Spree
  module Fulfillments
    # Keeps a fulfillment's `delivered` honest about its consignments.
    #
    # A fulfillment travels as one parcel most of the time, but not always: a
    # single gym rack is one line item in three boxes, each with its own
    # tracking number and its own carrier journey. So `delivered` is not a
    # flag anyone sets — it is the answer to "has every parcel arrived?",
    # recomputed whenever that answer could have changed: a carrier reports an
    # arrival, a merchant adds a fourth box, or removes one.
    #
    # It moves in both directions. Adding a parcel to a fulfillment already
    # marked delivered steps it back to `fulfilled`, because the goods are out
    # and not all of them have landed — saying otherwise would misdate the
    # returns window, which counts from arrival.
    #
    # A fulfillment with no consignments at all is left alone. Pickup, hand
    # delivery and freight with no carrier feed are delivered by staff saying
    # so, and there is nothing here to compute from.
    class RecalculateDelivery
      prepend Spree::ServiceModule::Base

      # @param fulfillment [Spree::Fulfillment]
      # @param notify_customer [Boolean] whether completing the delivery
      #   emails the customer
      # @return [Spree::ServiceModule::Result] the fulfillment
      def call(fulfillment:, notify_customer: true)
        # The caller has usually just written a delivery through another
        # object, so the loaded collection may still hold the old picture.
        fulfillment.deliveries.reset
        deliveries = fulfillment.deliveries

        return success(fulfillment) if deliveries.empty?

        if deliveries.undelivered.exists?
          return success(fulfillment) unless fulfillment.delivered?

          return reopen(fulfillment)
        end

        return success(fulfillment) unless fulfillment.can_mark_delivered?

        result = Spree.fulfillment_mark_delivered_workflow.call(
          fulfillment: fulfillment,
          delivered_at: deliveries.maximum(:delivered_at),
          notify_customer: notify_customer
        )
        result.success? ? success(fulfillment.reload) : failure(fulfillment, result.error.to_s)
      end

      private

      # Back to handed-over. `delivered_at` is cleared with it: it stamps when
      # the whole fulfillment arrived, and that is no longer true.
      def reopen(fulfillment)
        fulfillment.update!(status: 'fulfilled', delivered_at: nil)
        fulfillment.order&.update_statuses!
        success(fulfillment)
      end
    end
  end
end
