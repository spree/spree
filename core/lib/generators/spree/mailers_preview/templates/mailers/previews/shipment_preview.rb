class ShipmentPreview < ActionMailer::Preview
  def shipped_email
    Spree::ShipmentMailer.shipped_email(Spree::Shipment.last)
  end
end
