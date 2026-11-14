module Spree
  # Constant alias for the legacy Spree::Prototype class, renamed to
  # Spree::ProductType in 6.0. The warning fires when this
  # file loads. Removed in 6.5.
  Prototype = ProductType

  Spree::Deprecation.warn('Spree::Prototype is deprecated and will be removed in Spree 6.5. Use Spree::ProductType instead.')
end
