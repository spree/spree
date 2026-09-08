module Spree
  module Purchase
    # Finding a line item by the variant it sells, shared by Spree::Cart and
    # Spree::Order. Promotions and the coupon handler reach for these on
    # whichever of the two they were handed, so both have to answer.
    module LineItemLookup
      # @param variant [Spree::Variant]
      # @param options [Hash] passed to the line item comparison service
      # @return [Integer] units of the variant already on this purchase
      def quantity_of(variant, options = {})
        find_line_item_by_variant(variant, options)&.quantity || 0
      end

      # @param variant [Spree::Variant]
      # @param options [Hash] passed to the line item comparison service
      # @return [Spree::LineItem, nil]
      def find_line_item_by_variant(variant, options = {})
        line_items.detect do |line_item|
          line_item.variant_id == variant.id &&
            Spree.cart_compare_line_items_service.new.call(order: self, line_item: line_item, options: options).value
        end
      end
    end
  end
end
