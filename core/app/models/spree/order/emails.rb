module Spree
  class Order < Spree.base_class
    module Emails
      extend ActiveSupport::Concern

      def deliver_order_confirmation_email
        Spree::Deprecation.warn('Spree::Order#deliver_order_confirmation_email is deprecated and will be removed in Spree 5.5. Please create a Subscriber for order.completed event.')
      end

      # If you would like to also send confirmation email to store owner(s)
      def deliver_store_owner_order_notification_email?
        false
      end

      def deliver_store_owner_order_notification_email
        Spree::Deprecation.warn('Spree::Order#deliver_store_owner_order_notification_email is deprecated and will be removed in Spree 5.5. Please create a Subscriber for order.completed event.')
      end

      def send_cancel_email
        Spree::Deprecation.warn('Spree::Order#send_cancel_email is deprecated and will be removed in Spree 5.5. Please create a Subscriber for order.canceled event.')
      end
    end
  end
end
