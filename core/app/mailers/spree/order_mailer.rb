module Spree
  class OrderMailer < BaseMailer
    def confirm_email(order, resend = false)
      find_order(order)
      subject = (resend ? "[#{t(:resend).upcase}] " : '')
      subject += "#{Spree::Config[:site_name]} #{t('order_mailer.confirm_email.subject')} ##{@order.number}"
      mail(:to => @order.email, :from => from_address, :subject => subject)
    end

    def cancel_email(order, resend = false)
      find_order(order)
      subject = (resend ? "[#{t(:resend).upcase}] " : '')
      subject += "#{Spree::Config[:site_name]} #{t('order_mailer.cancel_email.subject')} ##{@order.number}"
      mail(:to => @order.email, :from => from_address, :subject => subject)
    end

    private
      def find_order(order)
        @order = order.is_a?(Spree::Order) ? order : Spree::Order.find(order)
      end
  end
end
