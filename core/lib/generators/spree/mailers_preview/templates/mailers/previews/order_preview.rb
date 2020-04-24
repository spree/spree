class OrderPreview < ActionMailer::Preview
  def confirm_email
    Spree::OrderMailer.confirm_email(Spree::Order.complete.first)
  end

  def cancel_email
    Spree::OrderMailer.cancel_email(Spree::Order.complete.first)
  end
end
