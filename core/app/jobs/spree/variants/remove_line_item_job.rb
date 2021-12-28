module Spree
  module Variants
    class RemoveLineItemJob < Spree::BaseJob
      def perform(line_item:)
        Spree::Dependencies.cart_remove_line_item_service.constantize.call(order: line_item.order, line_item: line_item)
      end
    end
  end
end
