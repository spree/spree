class OrderMailer < ActionMailer::Base
  helper "spree/base"
  default :from => "sean@railsdog.com"#Spree::Config[:order_from]

  def confirm_email(order, resend=false)
    @order = order
    subject = (resend ? "[RESEND] " : "")
    subject += Spree::Config[:site_name] + ' ' + 'Order Confirmation #' + order.number
    mail(:to => order.email,
         :subject => subject)
  end

  # TODO - cancel email
  # TODO -bcc stuff
end
