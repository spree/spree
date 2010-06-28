class OrderMailer < ActionMailer::Base
  helper "spree/base"
  default :from => Spree::Config[:order_from]

  def confirm(order, resend = false)
    @subject    = (resend ? "[RESEND] " : "")
    @subject    += Spree::Config[:site_name] + ' ' + 'Order Confirmation #' + order.number
    mail(:subject => @subject, :body =>  {"order" => order}, :to => order.email, :bcc => order_bcc)
  end

  def cancel(order)
    @subject    = '[CANCEL]' + Spree::Config[:site_name] + ' Order Confirmation #' + order.number
    mail(:subject => @subject, :body =>  {"order" => order}, :to => order.email, :bcc => order_bcc)
  end

  private
  def order_bcc
      bcc = [Spree::Config[:order_bcc] || "", Spree::Config[:mail_bcc] || ""]
      bcc = bcc.inject([]){|array, config_string| array + config_string.split(",")}
      bcc = bcc.collect{|email| email.strip}
      bcc = bcc.uniq
      bcc
  end
end
