module Spree
  # The purchase a customer made, when it produced more than one order.
  #
  # A checkout spanning several sellers divides into one order per seller, and
  # no one of them is the purchase — each holds a single seller's items,
  # delivery and total. So the confirmation is sent from the group: one email
  # naming the number the customer saw at checkout, every item they bought, the
  # total they actually paid, and the parcels it will arrive in.
  #
  # Kept separate from +Spree::OrderMailer+ rather than folded into it: a
  # checkout that does not split is still one order and still sends that
  # email unchanged, and a storefront replacing one document should not have to
  # inherit the other.
  class OrderGroupMailer < BaseMailer
    helper Spree::MailHelper

    # @param order_group [Spree::OrderGroup, Integer, String] record or id
    # @param resend [Boolean] prefixes the subject, for an admin re-send
    def confirm_email(order_group, resend = false)
      @order_group = find_order_group(order_group)
      # Assigned rather than left to BaseMailer#current_store, which memoizes
      # off @order and would otherwise fall back to the default store — the
      # wrong store's name, logo and footer on a multi-store install.
      @current_store = @order_group.store

      with_store_locale(@current_store, @order_group.locale) do
        subject = order_email_subject(
          @current_store, Spree.t('order_group_mailer.confirm_email.subject'), @order_group.number, resend: resend
        )
        mail(to: @order_group.email, subject: subject, store_url: @current_store.storefront_url)
      end
    end

    def store_owner_notification_email(order_group)
      @order_group = find_order_group(order_group)
      @current_store = @order_group.store

      with_store_locale(@current_store) do
        subject = Spree.t('order_group_mailer.store_owner_notification_email.subject', store_name: @current_store.name)
        mail(to: @current_store.new_order_notifications_email, subject: subject,
             store_url: @current_store.storefront_url)
      end
    end

    private

    def find_order_group(order_group)
      order_group.respond_to?(:id) ? order_group : Spree::OrderGroup.find(order_group)
    end
  end
end
