module Spree
  module Variants
    class RemoveLineItemJob < Spree::BaseJob
      queue_as Spree.queues.variants

      def perform(line_item:)
        Spree.cart_remove_line_item_service.call(order: line_item.order, line_item: line_item)
      end
    end
  end
end
