module Spree
  class Order < Spree.base_class
    module Webhooks
      extend ActiveSupport::Concern

      def send_order_canceled_webhook
        # Implement your logic of sending cancale webhooks
      end

      def send_order_placed_webhook
        # Implement your logic of sending order placed webhooks
      end

      def send_order_resumed_webhook
        # Implement your logic of sending after resume webhooks
      end
    end
  end
end
