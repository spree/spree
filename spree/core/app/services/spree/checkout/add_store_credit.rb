module Spree
  module Checkout
    # @deprecated Renamed to Spree::StoreCredits::Apply for symmetry with
    #   Spree::GiftCards::Apply; removed in 6.1. A constant alias rather than
    #   a subclass, so is_a? and class_name: references keep resolving.
    AddStoreCredit = Spree::StoreCredits::Apply

    # @deprecated Renamed to Spree::StoreCredits::Remove; removed in 6.1.
    RemoveStoreCredit = Spree::StoreCredits::Remove

    Spree::Deprecation.warn(
      'Spree::Checkout::AddStoreCredit and Spree::Checkout::RemoveStoreCredit are deprecated ' \
      'and will be removed in Spree 6.1. Use Spree::StoreCredits::Apply and ' \
      'Spree::StoreCredits::Remove instead.'
    )
  end
end
