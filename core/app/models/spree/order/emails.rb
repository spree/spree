module Spree
  class Order < Spree::Base
    module Emails
      extend ActiveSupport::Concern

      def deliver_order_confirmation_email
        # you can overwrite this method in your application / extension to send out the confirmation email
        # or use `spree_emails` gem
        # YourEmailVendor.deliver_order_confirmation_email(id) # `id` = ID of the Order being sent, you can also pass the entire Order object using `self`
        # update_column(:confirmation_delivered, true) # if you would like to mark that the email was sent
      end

      # If you would like to also send confirmation email to store owner(s)
      def deliver_store_owner_order_notification_email?
        false
      end

      def deliver_store_owner_order_notification_email
        # you can overwrite this method in your application / extension to send out the confirmation email
        # or use `spree_emails` gem
        # YourEmailVendor.deliver_store_owner_notification_email(id) # `id` = ID of the Order being sent, you can also pass the entire Order object using `self`
        # update_column(:store_owner_notification_delivered, true) # if you would like to mark that the email was sent
      end

      def send_cancel_email
        # you can overwrite this method in your application / extension to send out the confirmation email
        # or use `spree_emails` gem
        # YourEmailVendor.deliver_cancel_email(id) # `id` = ID of the Order being sent, you can also pass the entire Order object using `self`
      end
    end
  end
end
