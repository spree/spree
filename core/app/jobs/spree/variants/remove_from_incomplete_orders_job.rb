module Spree
  module Variants
    class RemoveFromIncompleteOrdersJob < Spree::BaseJob
      def perform(variant)
        Spree::Variants::RemoveLineItems.call(variant: variant)
      end
    end
  end
end
