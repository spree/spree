module Spree
  class Order < Spree.base_class
    module Emails
      def deliver_order_confirmation_email
        if completed?
          OrderMailer.confirm_email(id).deliver_later if store.prefers_send_consumer_transactional_emails?
          update_column(:confirmation_delivered, true)
        else
          errors.add(:base, Spree.t(:order_email_resent_error))
        end
      end

      # Returns true if:
      #   1. an email address is set for new order notifications AND
      #   2. no notification for this order has been sent yet.
      def deliver_store_owner_order_notification_email?
        store.new_order_notifications_email.present? && !store_owner_notification_delivered?
      end

      def deliver_store_owner_order_notification_email
        OrderMailer.store_owner_notification_email(id).deliver_later
        update_column(:store_owner_notification_delivered, true)
      end

      def send_cancel_email
        OrderMailer.cancel_email(id).deliver_later
      end
    end
  end
end
