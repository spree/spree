class ShipmentPreview < ActionMailer::Preview
  helper Spree::ShipmentHelper

  def shipped_email
    Spree::ShipmentMailer.shipped_email(Spree::Shipment.shipped.first)
  end
end
