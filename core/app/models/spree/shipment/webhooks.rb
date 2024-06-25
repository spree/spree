module Spree
  class Shipment < Spree::Base
    module Webhooks
      extend ActiveSupport::Concern

      def send_shipment_shipped_webhook
        # Implement your logic here
      end
    end
  end
end
