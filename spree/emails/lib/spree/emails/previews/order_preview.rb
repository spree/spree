require 'spree/core/previews/preview_data'

# Preview Spree order emails at /rails/mailers/spree/order
class Spree::OrderPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def confirm_email
    Spree::OrderMailer.confirm_email(order)
  end

  def cancel_email
    Spree::OrderMailer.cancel_email(order)
  end

  def store_owner_notification_email
    Spree::OrderMailer.store_owner_notification_email(order)
  end

  private

  # The most recent complete order, with its locale overridden in memory when the
  # preview toolbar requests one (the change is never saved).
  def order
    order = Spree::Order.complete.last
    order.locale = locale if order && locale.present?
    order
  end
end
