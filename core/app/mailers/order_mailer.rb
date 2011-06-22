class OrderMailer < ActionMailer::Base
  helper "spree/base"

  def confirm_email(order, resend=false)
    @order = order
    subject = (resend ? "[RESEND] " : "")
    subject += "#{Spree::Config[:site_name]} #{t('subject', :scope =>'order_mailer.confirm_email')} ##{order.number}"
    mail(:to => order.email,
         :subject => subject)
  end
  
  def new_order_email(order)
    @order = order
    subject = "#{Spree::Config[:site_name]} #{t('subject', :scope =>'order_mailer.new_order_email', :default => 'You received a new order')} ##{order.number}"
    mail(:to => Spree::Config[:new_order_email],
         :subject => subject)
  end
  
  def cancel_email(order, resend=false)
    @order = order
    subject = (resend ? "[RESEND] " : "")
    subject += "#{Spree::Config[:site_name]} #{t('subject', :scope => 'order_mailer.cancel_email')} ##{order.number}"
    mail(:to => order.email,
         :subject => subject)
  end
end
