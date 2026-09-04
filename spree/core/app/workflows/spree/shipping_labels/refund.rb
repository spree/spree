module Spree
  module ShippingLabels
    # Asks the carrier to refund a purchased label. The carrier answers
    # either way at once (+refunded+) or later (+refund_requested+, settled
    # through Spree::ShippingLabels::ConfirmRefund); an uploaded label has
    # nothing to refund and is deleted instead.
    #
    # The delivery the label minted is removed only when the consignment
    # never moved — once the parcel has shipped the journey is history and
    # the delivery stays, label or no label.
    class Refund < Spree::Workflow
      hooks :validate, :after_refund

      # @param shipping_label [Spree::ShippingLabel]
      # @return [Spree::ServiceModule::Result] the label on success
      def perform(shipping_label:)
        super

        run_hooks :validate

        step :ensure_refundable

        # Carrier I/O — never inside a transaction.
        external_step :refund

        ApplicationRecord.transaction do
          step :record_outcome
          step :remove_delivery_if_never_moved
        end

        shipping_label.publish_event('shipping_label.refunded') if shipping_label.refunded?
        run_hooks :after_refund
        success(shipping_label.reload)
      end

      private

      # A label the carrier is still deciding on is re-askable: some carriers
      # settle refunds asynchronously, and re-filing is how a request that
      # never came back is re-driven.
      def ensure_refundable
        return if shipping_label.refundable?

        reason = shipping_label.uploaded? ? 'uploaded_not_refundable' : 'not_refundable'
        failure(shipping_label, Spree.t("shipping_labels.errors.#{reason}"))
      end

      def refund
        @outcome = shipping_label.provider.refund_label(shipping_label).to_s

        return if %w[refunded refund_requested].include?(@outcome)

        failure(shipping_label, Spree.t('shipping_labels.errors.refund_failed'))
      end

      def record_outcome
        attributes = { status: @outcome }
        attributes[:refunded_at] = Time.current if @outcome == 'refunded'
        shipping_label.update!(attributes)
      end

      def remove_delivery_if_never_moved
        shipping_label.release_unmoved_delivery
      end
    end
  end
end
