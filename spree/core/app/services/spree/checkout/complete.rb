module Spree
  module Checkout
    # @deprecated Use Spree::Carts::Complete; removed in 6.1.
    class Complete
      prepend Spree::ServiceModule::Base

      def call(order:)
        Spree::Deprecation.warn('Spree::Checkout::Complete is deprecated and will be removed in Spree 6.1. Use Spree::Carts::Complete instead.')
        Spree::Dependencies.carts_complete_workflow.constantize.call(cart: order)
      end
    end
  end
end
