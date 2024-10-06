module Spree
  module Variants
    class RemoveLineItemJob < Spree::BaseJob
      queue_as Spree.queues.variants

      def perform(line_item:)
        Spree::Dependencies.cart_remove_line_item_service.constantize.call(order: line_item.order, line_item: line_item)
      end
    end
  end
end
