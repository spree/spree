module Spree
  class Product < Spree::Base
    module Webhooks
      def send_product_activated_webhook
        # Implement your logic here
      end

      def send_product_archived_webhook
        # Implement your logic here
      end

      def send_product_drafted_webhook
        # Implement your logic here
      end
    end
  end
end
