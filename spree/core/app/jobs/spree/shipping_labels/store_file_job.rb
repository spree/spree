module Spree
  module ShippingLabels
    # Retries fetching a purchased label's file when the fetch right after
    # purchase failed — the carrier's hosted copy is usually there a moment
    # later. Idempotent: an already-attached file is left alone.
    class StoreFileJob < Spree::BaseJob
      retry_on StandardError, wait: :polynomially_longer, attempts: 5

      # @param shipping_label_id [Integer]
      def perform(shipping_label_id)
        shipping_label = Spree::ShippingLabel.find(shipping_label_id)
        result = Spree.shipping_label_store_file_service.call(shipping_label: shipping_label)
        raise result.error.to_s if result.failure?
      end
    end
  end
end
