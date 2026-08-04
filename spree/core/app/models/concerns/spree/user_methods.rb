module Spree
  # Deprecation alias for Spree::CustomerMethods, renamed from Spree::UserMethods in 6.0.
  # True constant alias — the underlying module, its associations, and prefix (cust)
  # are all Spree::CustomerMethods. Remove in Spree 6.1.
  UserMethods = CustomerMethods
  Spree::Deprecation.warn('Spree::UserMethods is deprecated and will be removed in Spree 6.1. Use Spree::CustomerMethods instead.')
end
