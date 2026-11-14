module Spree
  # Constant alias for the legacy Spree::Shipment, renamed to
  # Spree::Fulfillment in 6.0. The warning fires when this
  # file loads. Removed in 6.3.
  Shipment = Fulfillment

  Spree::Deprecation.warn('Spree::Shipment is deprecated and will be removed in Spree 6.3. Use Spree::Fulfillment instead.')
end
