require 'spree/core/previews/preview_data'

# Preview Spree fulfillment emails at /rails/mailers/spree/fulfillment
class Spree::FulfillmentPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def fulfilled_email
    fulfillment = Spree::Fulfillment.fulfilled.last
    fulfillment.order.locale = locale if fulfillment && locale.present?
    Spree::FulfillmentMailer.fulfilled_email(fulfillment)
  end
end
