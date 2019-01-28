module Spree
  module LineItems
    class FindByVariant
      def execute(order:, variant:, options: {})
        order.line_items.detect do |line_item|
          next unless line_item.variant_id == variant.id

          Spree::Dependencies.cart_compare_line_items_service.constantize.call(order: order, line_item: line_item, options: options).value
        end
      end
    end
  end
end
