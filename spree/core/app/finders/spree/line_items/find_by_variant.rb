module Spree
  module LineItems
    class FindByVariant
      def execute(order:, variant:, options: {})
        line_item = order.line_items.loaded? ? order.line_items.detect { |li| li.variant_id == variant.id } : order.line_items.find_by(variant_id: variant.id)

        if line_item
          result = Spree.cart_compare_line_items_service.call(order: order, line_item: line_item, options: options).value
          return nil unless result
        end

        line_item
      end
    end
  end
end
