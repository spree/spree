class OrderMailer < ActionMailer::Base
  helper "spree/base"
  
  def confirm(order, resend = false)
    @subject    = (resend ? "[RESEND] " : "") 
    @subject    += 'Order Confirmation #' + order.number
    @body       = {"order" => order}
    @recipients = order.user.email
    @from       = Spree::Config[:order_from]
    @bcc        = order_bcc
    @sent_on    = Time.now
  end
  
  def cancel(order)
    @subject    = '[CANCEL] Order Confirmation #' + order.number
    @body       = {"order" => order}
    @recipients = order.user.email
    @from       = Spree::Config[:order_from]
    @bcc        = order_bcc
    @sent_on    = Time.now
  end  
  
  private
  def order_bcc
    [Spree::Config[:order_bcc], Spree::Config[:mail_bcc]].uniq
  end
end
