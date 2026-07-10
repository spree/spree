module Spree
  class OrderMailer < BaseMailer
    helper Spree::MailHelper

    def confirm_email(order, resend = false)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      current_store = @order.store
      with_store_locale(current_store, @order.locale) do
        subject = order_email_subject(current_store, Spree.t('order_mailer.confirm_email.subject'), @order.number, resend: resend)
        mail(to: @order.email, from: from_address, subject: subject, store_url: current_store.storefront_url)
      end
    end

    def store_owner_notification_email(order)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      current_store = @order.store
      with_store_locale(current_store) do
        subject = Spree.t('order_mailer.store_owner_notification_email.subject', store_name: current_store.name)
        mail(to: current_store.new_order_notifications_email, from: from_address, subject: subject, store_url: current_store.storefront_url)
      end
    end

    def cancel_email(order, resend = false)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      current_store = @order.store
      with_store_locale(current_store, @order.locale) do
        subject = order_email_subject(current_store, Spree.t('order_mailer.cancel_email.subject'), @order.number, resend: resend)
        mail(to: @order.email, from: from_address, subject: subject, store_url: current_store.storefront_url)
      end
    end

    def payment_link_email(order_id)
      @order = Spree::Order.incomplete.not_canceled.find(order_id)
      @current_store = @order.store
      @checkout_payment_url = spree.checkout_state_url(@order.token, :payment, host: @current_store.storefront_url)

      with_store_locale(@current_store, @order.locale) do
        mail(to: @order.email, from: from_address, subject: Spree.t('order_mailer.payment_link_email.subject', number: @order.number),
             store_url: @current_store.storefront_url)
      end
    end
  end
end
