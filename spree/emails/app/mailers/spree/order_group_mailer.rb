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
    # @param order_group [Spree::OrderGroup, Integer, String] record or id
    # @param resend [Boolean] prefixes the subject, for an admin re-send
    def confirm_email(order_group, resend = false)
      @order_group = find_order_group(order_group)
      deliver_order_group_email(to: @order_group.email, locale: @order_group.locale, resend: resend)
    end

    def store_owner_notification_email(order_group)
      @order_group = find_order_group(order_group)
      deliver_order_group_email(to: @order_group.store.new_order_notifications_email)
    end

    private

    def find_order_group(order_group)
      order_group.respond_to?(:id) ? order_group : Spree::OrderGroup.find(order_group)
    end

    def deliver_order_group_email(to:, locale: nil, resend: false)
      # Assigned rather than left to BaseMailer#current_store, which memoizes
      # off @order and would otherwise fall back to the default store — the
      # wrong store's name, logo and footer on a multi-store install.
      @current_store = @order_group.store

      with_store_locale(@current_store, locale) do
        mail_template(
          { order_group: email_data(@order_group, Spree::Emails::OrderGroupSerializer), resend: resend },
          to: to, store_url: @current_store.storefront_url
        )
      end
    end
  end
end
