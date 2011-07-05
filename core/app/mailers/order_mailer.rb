class OrderMailer < ActionMailer::Base
  helper "spree/base"

  def confirm_email(order, resend=false)
    @order = order
    subject = (resend ? "[RESEND] " : "")
    subject += "#{Spree::Config[:site_name]} #{t('subject', :scope =>'order_mailer.confirm_email')} ##{order.number}"
    mail(:to => order.email,
         :subject => subject) do |format|
            format.text
            format.html
    end
  end

  def capture_email(order, resend=false)
    @order = order
    subject = (resend ? "[RESEND] " : "")
    subject += "#{Spree::Config[:site_name]} #{t('subject', :scope =>'order_mailer.capture_email')} ##{order.number}"
    mail(:to => order.email,
         :subject => subject) do |format|
            format.text
            format.html
    end
  end

  def void_email(order, resend=false)
    @order = order
    subject = (resend ? "[RESEND] " : "")
    subject += "#{Spree::Config[:site_name]} #{t('subject', :scope =>'order_mailer.void_email')} ##{order.number}"
    mail(:to => order.email,
         :subject => subject) do |format|
            format.text
            format.html
    end
  end

  def cancel_email(order, resend=false)
    @order = order
    subject = (resend ? "[RESEND] " : "")
    subject += "#{Spree::Config[:site_name]} #{t('subject', :scope => 'order_mailer.cancel_email')} ##{order.number}"
    mail(:to => order.email,
         :subject => subject) do |format|
            format.text
            format.html
    end
  end
end
