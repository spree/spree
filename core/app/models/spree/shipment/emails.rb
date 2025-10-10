module Spree
  class Shipment < Spree.base_class
    module Emails
      def send_shipped_email
        # you can overwrite this method in your application / extension to send out the confirmation email
        # or use `spree_emails` gem
        # YourEmailVendor.deliver_shipment_notification_email(@shipment.id)
      end
    end
  end
end
