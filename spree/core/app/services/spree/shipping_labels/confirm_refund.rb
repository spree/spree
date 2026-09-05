module Spree
  module ShippingLabels
    # Settles a refund the carrier answered later. Providers whose refunds
    # resolve asynchronously call this from their webhook handler once the
    # carrier confirms; the label moves from +refund_requested+ to
    # +refunded+ and the same event fires as for a synchronous refund.
    class ConfirmRefund
      prepend Spree::ServiceModule::Base

      # @param shipping_label [Spree::ShippingLabel]
      # @param refunded_at [Time, nil] when the carrier settled it; defaults to now
      # @return [Spree::ServiceModule::Result]
      def call(shipping_label:, refunded_at: nil)
        return success(shipping_label) if shipping_label.refunded?

        unless shipping_label.refund_requested?
          shipping_label.errors.add(:base, :not_refund_requested, message: Spree.t('shipping_labels.errors.not_refund_requested'))
          return failure(shipping_label)
        end

        # Carriers retry webhooks, so two confirmations can arrive at once and
        # both read `refund_requested`. The settle is a conditional UPDATE:
        # exactly one call moves the row, and only that one releases the
        # delivery and announces the refund.
        settled = ApplicationRecord.transaction do
          claimed = Spree::ShippingLabel.
            where(id: shipping_label.id, status: 'refund_requested').
            update_all(status: 'refunded', refunded_at: refunded_at || Time.current, updated_at: Time.current)

          # The delivery goes with the settle or neither happens: a refunded
          # label still holding the consignment it minted is the state a
          # retry cannot detect, since the status already reads refunded.
          shipping_label.reload.release_unmoved_delivery if claimed.positive?
          claimed
        end

        return success(shipping_label.reload) if settled.zero?

        # Outside the transaction deliberately — subscribers do their own
        # work, and a slow or failing one must not roll back a refund the
        # carrier has already made.
        shipping_label.publish_event('shipping_label.refunded')
        success(shipping_label)
      end
    end
  end
end
