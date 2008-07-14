class OrderMailer < ActionMailer::Base
  helper "spree/base"
  
  def confirm(order, resend = false)
    @subject    = (resend ? "[RESEND] " : "") 
    @subject    += 'Order Confirmation #' + order.number
    @body       = {"order" => order}
    @recipients = order.user.email
    @from       = Spree::Config[:order_from]
    @bcc        = ORDER_BCC unless ORDER_BCC.empty? or resend
    @sent_on    = Time.now
  end
  
  def cancel(order)
    @subject    = '[CANCEL] Order Confirmation #' + order.number
    @body       = {"order" => order}
    @recipients = order.user.email
    @from       = Spree::Config[:order_from]
    @bcc        = ORDER_BCC unless ORDER_BCC.empty?
    @sent_on    = Time.now
  end  
end
