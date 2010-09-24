class ShipmentMailer < ActionMailer::Base
  helper "spree/base"

  default :from => "sean@railsdog.com"#Spree::Config[:order_from]

  def shipped_email(shipment, resend=false)
    @shipment = shipment
    subject = (resend ? "[RESEND] " : "")
    subject += "#{Spree::Config[:site_name]} Shipment Notification ##{shipment.order.number}"
    mail(:to => shipment.order.email,
         :subject => subject)
  end
end