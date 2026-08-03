module Spree
  # Deprecated: use Spree::FulfillmentMailer. Removed in Spree 6.1.
  class ShipmentMailer < FulfillmentMailer
    def shipped_email(shipment, resend = false)
      Spree::Deprecation.warn('Spree::ShipmentMailer#shipped_email is deprecated and will be removed in Spree 6.1. Use Spree::FulfillmentMailer#fulfilled_email instead.')
      fulfilled_email(shipment, resend)
    end
  end
end
