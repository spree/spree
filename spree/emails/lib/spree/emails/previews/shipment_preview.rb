require 'spree/core/previews/preview_data'

# Preview Spree shipment emails at /rails/mailers/spree/shipment
class Spree::ShipmentPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def shipped_email
    shipment = Spree::Shipment.shipped.last
    shipment.order.locale = locale if shipment && locale.present?
    Spree::ShipmentMailer.shipped_email(shipment)
  end
end
