module Spree
  module Fulfillments
    # The carrier half of cancelling a parcel: every active label is refunded
    # and the provider is told to drop any non-label dispatch (a 3PL pick).
    # Network I/O, so callers run it from an external step after their own
    # transaction has committed — Spree::Fulfillments::Cancel directly,
    # Spree::Orders::Cancel batched over every fulfillment on the order.
    #
    # Nothing here blocks the cancellation: the goods are not going out
    # either way, and a refund the carrier refuses surfaces on the label.
    class StandDownProvider
      prepend Spree::ServiceModule::Base

      # @param fulfillment [Spree::Fulfillment]
      # @return [Spree::ServiceModule::Result]
      def call(fulfillment:)
        fulfillment.shipping_labels.active.each do |shipping_label|
          next unless shipping_label.refundable?

          result = Spree.shipping_label_refund_workflow.call(shipping_label: shipping_label)
          next if result.success?

          # The goods are not going out either way, so a carrier that refuses
          # the refund never blocks the cancellation — but the merchant is out
          # of pocket, so it is reported rather than swallowed.
          Rails.error.report(
            Spree::Core::LabelRefundFailed.new(result.error.to_s),
            context: { shipping_label_id: shipping_label.id, fulfillment_id: fulfillment.id },
            source: 'spree.fulfillments.stand_down'
          )
        end

        fulfillment.provider.cancel_fulfillment(fulfillment)
        success(fulfillment)
      end
    end
  end
end
