module Spree
  class Payment < Spree.base_class
    module Webhooks
      extend ActiveSupport::Concern

      def send_payment_voided_webhook
        # Implement your logic here
      end

      def send_payment_completed_webhook
        # Implement your logic here
      end
    end
  end
end
