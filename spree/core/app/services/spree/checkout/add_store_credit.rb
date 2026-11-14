module Spree
  module Checkout
    # Deprecation alias for Spree::StoreCredits::Apply, renamed in 6.0 for
    # symmetry with Spree::GiftCards::Apply. Retained until 6.3 so existing
    # code and extensions keep working. A constant assignment rather than a
    # subclass, so is_a? and class_name: references keep resolving; the file
    # is named for the constant because Zeitwerk requires it. Removed in 6.3.
    AddStoreCredit = Spree::StoreCredits::Apply

    Spree::Deprecation.warn(
      'Spree::Checkout::AddStoreCredit is deprecated and will be removed in Spree 6.3. ' \
      'Use Spree::StoreCredits::Apply instead.'
    )
  end
end
