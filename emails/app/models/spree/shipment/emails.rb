module Spree
  class Shipment < Spree.base_class
    module Emails
      def send_shipped_email
        ShipmentMailer.shipped_email(@shipment.id).deliver_later if @shipment.store.prefers_send_consumer_transactional_emails?
      end
    end
  end
end
