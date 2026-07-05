# Preview Spree shipment emails at /rails/mailers/spree/shipment
class Spree::ShipmentPreview < ActionMailer::Preview
  def shipped_email
    Spree::ShipmentMailer.shipped_email(Spree::Shipment.shipped.last)
  end
end
