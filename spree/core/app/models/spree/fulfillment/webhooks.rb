module Spree
  class Fulfillment < Spree.base_class
    module Webhooks
      extend ActiveSupport::Concern

      def send_fulfillment_fulfilled_webhook
        # Implement your logic here
      end

      # @deprecated Use {#send_fulfillment_fulfilled_webhook}; removed in 6.1.
      def send_shipment_shipped_webhook
        Spree::Deprecation.warn('Spree::Fulfillment#send_shipment_shipped_webhook is deprecated and will be removed in Spree 6.1. Use #send_fulfillment_fulfilled_webhook instead.')
        send_fulfillment_fulfilled_webhook
      end
    end
  end
end
