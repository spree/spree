class OrderMailer < ActionMailer::QueueMailer
  helper "spree/base"
  
  def confirm(order, resend = false)
    @subject    = (resend ? "[RESEND] " : "") 
    @subject    += Spree::Config[:site_name] + ' ' + 'Order Confirmation #' + order.number
    @body       = {"order" => order}
    @recipients = order.email
    @from       = Spree::Config[:order_from]
    @bcc        = order_bcc
    @sent_on    = Time.now
  end
  
  def cancel(order)
    @subject    = '[CANCEL]' + Spree::Config[:site_name] + ' Order Confirmation #' + order.number
    @body       = {"order" => order}
    @recipients = order.email
    @from       = Spree::Config[:order_from]
    @bcc        = order_bcc
    @sent_on    = Time.now
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
