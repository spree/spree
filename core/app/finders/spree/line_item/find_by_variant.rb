module Spree
  class LineItem
    class FindByVariant
      prepend Spree::Callable

      def call(order:, variant:, options: {})
        order.line_items.detect do |line_item|
          next unless line_item.variant_id == variant.id
          CompareLineItems.new.call(order: order, line_item: line_item, options: options).value
        end
      end
    end
  end
end
