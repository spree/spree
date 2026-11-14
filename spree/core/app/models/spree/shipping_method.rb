module Spree
  # Constant alias for the legacy Spree::ShippingMethod, renamed to
  # Spree::DeliveryMethod in 6.0. The warning fires when this
  # file loads. Removed in 6.5.
  ShippingMethod = DeliveryMethod

  Spree::Deprecation.warn('Spree::ShippingMethod is deprecated and will be removed in Spree 6.5. Use Spree::DeliveryMethod instead.')
end
