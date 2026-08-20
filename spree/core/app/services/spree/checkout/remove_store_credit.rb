module Spree
  module Checkout
    # Deprecation alias for Spree::StoreCredits::Remove — see
    # Spree::Checkout::AddStoreCredit. Removed in 6.1.
    RemoveStoreCredit = Spree::StoreCredits::Remove

    Spree::Deprecation.warn(
      'Spree::Checkout::RemoveStoreCredit is deprecated and will be removed in Spree 6.1. ' \
      'Use Spree::StoreCredits::Remove instead.'
    )
  end
end
