module Spree
  class Shipment < Spree::Base
    module Emails
      def send_shipped_email
        ShipmentMailer.shipped_email(@shipment.id).deliver_later
      end
    end
  end
end
