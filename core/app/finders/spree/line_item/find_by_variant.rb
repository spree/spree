module Spree
  class LineItem < Spree::Base
    class FindByVariant
      def execute(order:, variant:, options: {})
        order.line_items.detect do |line_item|
          next unless line_item.variant_id == variant.id
          CompareLineItems.new.call(order: order, line_item: line_item, options: options).value
        end
      end
    end
  end
end
