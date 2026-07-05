# Preview Spree order emails at /rails/mailers/spree/order
class Spree::OrderPreview < ActionMailer::Preview
  def confirm_email
    Spree::OrderMailer.confirm_email(Spree::Order.complete.last)
  end

  def cancel_email
    Spree::OrderMailer.cancel_email(Spree::Order.complete.last)
  end

  def store_owner_notification_email
    Spree::OrderMailer.store_owner_notification_email(Spree::Order.complete.last)
  end
end
