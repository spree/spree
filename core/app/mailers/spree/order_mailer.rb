module Spree
  class OrderMailer < ActionMailer::Base

    def money(amount)
      Spree::Money.new(amount).to_s
    end
    helper_method :money

    def from_address
      Spree::Config[:mails_from]
    end

    def confirm_email(order, resend = false)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      subject = (resend ? "[#{t(:resend).upcase}] " : '')
      subject += "#{Spree::Config[:site_name]} #{t('order_mailer.confirm_email.subject')} ##{@order.number}"
      mail(to: @order.email,
           from: from_address,
           subject: subject)
    end

    def cancel_email(order, resend = false)
      @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
      subject = (resend ? "[#{t(:resend).upcase}] " : '')
      subject += "#{Spree::Config[:site_name]} #{t('order_mailer.cancel_email.subject')} ##{@order.number}"
      mail(to: @order.email,
           from: from_address,
           subject: subject)
    end
  end
end
