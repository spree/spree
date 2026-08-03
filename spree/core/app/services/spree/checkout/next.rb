module Spree
  module Checkout
    # @deprecated There are no checkout states to advance since 6.0 —
    #   recalculates the cart and returns it. Removed in 6.1; use
    #   Spree::Checkout::Advance.
    class Next
      prepend Spree::ServiceModule::Base

      def call(order:)
        Spree::Deprecation.warn('Spree::Checkout::Next is deprecated and will be removed in Spree 6.1. Use Spree::Checkout::Advance instead.')
        Spree::Checkout::Advance.call(order: order)
      end
    end
  end
end
