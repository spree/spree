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
          shipping_label.errors.add(:base, Spree.t('shipping_labels.errors.not_refund_requested'))
          return failure(shipping_label)
        end

        ApplicationRecord.transaction do
          shipping_label.update!(status: 'refunded', refunded_at: refunded_at || Time.current)
          shipping_label.release_unmoved_delivery
        end

        shipping_label.publish_event('shipping_label.refunded')
        success(shipping_label)
      end
    end
  end
end
