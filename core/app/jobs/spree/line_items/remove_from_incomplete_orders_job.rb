module Spree
  module LineItems
    class RemoveFromIncompleteOrdersJob < Spree::BaseJob
      def perform(variant, order_ids)
        Spree::Variants::RemoveLineItems.call(variant: variant, order_ids: order_ids)
      end
    end
  end
end
