module Spree
  class Shipment < Spree.base_class
    module Emails
      def send_shipped_email
        ShipmentMailer.shipped_email(@shipment.id).deliver_later
      end
    end
  end
end
