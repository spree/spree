module Spree
  class OrderMailer < BaseMailer
    helper Spree::MailHelper

    def confirm_email(order, resend = false)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      current_store = @order.store
      subject = (resend ? "[#{Spree.t(:resend).upcase}] " : '')
      subject += "#{current_store.name} #{Spree.t('order_mailer.confirm_email.subject')} ##{@order.number}"
      mail(to: @order.email, from: from_address, subject: subject, store_url: current_store.url_or_custom_domain, reply_to: reply_to_address)
    end

    def store_owner_notification_email(order)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      current_store = @order.store
      subject = Spree.t('order_mailer.store_owner_notification_email.subject', store_name: current_store.name)
      mail(to: current_store.new_order_notifications_email, from: from_address, subject: subject, store_url: current_store.url_or_custom_domain, reply_to: reply_to_address)
    end

    def cancel_email(order, resend = false)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      current_store = @order.store
      subject = (resend ? "[#{Spree.t(:resend).upcase}] " : '')
      subject += "#{current_store.name} #{Spree.t('order_mailer.cancel_email.subject')} ##{@order.number}"
      mail(to: @order.email, from: from_address, subject: subject, store_url: current_store.url_or_custom_domain, reply_to: reply_to_address)
    end

    def payment_link_email(order_id)
      @order = Spree::Order.incomplete.not_canceled.find(order_id)
      @current_store = @order.store
      @checkout_payment_url = spree.checkout_state_url(@order.token, :payment, host: @current_store.url_or_custom_domain)

      mail(to: @order.email, from: from_address, subject: Spree.t('order_mailer.payment_link_email.subject', number: @order.number),
           store_url: @current_store.url_or_custom_domain, reply_to: reply_to_address)
    end
  end
end
