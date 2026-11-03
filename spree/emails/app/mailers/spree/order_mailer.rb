module Spree
  class OrderMailer < BaseMailer
    include Spree::Emails::OrderPageUrl

    def confirm_email(order, resend = false)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      deliver_order_email(to: @order.email, locale: @order.locale, resend: resend)
    end

    def store_owner_notification_email(order)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      deliver_order_email(to: current_store.new_order_notifications_email)
    end

    def cancel_email(order, resend = false)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      deliver_order_email(to: @order.email, locale: @order.locale, resend: resend)
    end

    def payment_link_email(order_id)
      @order = Spree::Order.incomplete.not_canceled.find(order_id)
      @current_store = @order.store
      # Carries the order token, so it is built here and never serialized.
      @checkout_payment_url = URI.join(@current_store.storefront_url, "/checkout/#{@order.token}/payment").to_s

      deliver_order_email(to: @order.email, locale: @order.locale, payment_url: @checkout_payment_url)
    end

    # The link a guest asked for from "find my order". Carries the order
    # token, so it is built here and never serialized, and it goes only to the
    # address the order was placed with.
    def lookup_email(order_id)
      @order = Spree::Order.complete.find(order_id)
      @current_store = @order.store
      @order_url = guest_order_url(@order)

      deliver_order_email(to: @order.email, locale: @order.locale, order_url: @order_url)
    end

    private

    def deliver_order_email(to:, locale: nil, **assigns)
      with_store_locale(current_store, locale) do
        mail_template(
          { order: email_data(@order, Spree::Emails::OrderSerializer), resend: false }.merge(assigns),
          to: to, store_url: current_store.storefront_url
        )
      end
    end
  end
end
