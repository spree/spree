class OrderPreview < ActionMailer::Preview
  def confirm_email
    Spree::OrderMailer.confirm_email(Spree::Order.first)
  end

  def cancel_email
    Spree::OrderMailer.cancel_email(Spree::Order.first)
  end
end
