module Spree
  module LineItems
    class FindByVariant
      # @param owner [Spree::Cart, Spree::Order] the line-item owner
      def execute(owner: nil, cart: nil, order: nil, variant:, options: {})
        owner ||= cart || order
        candidates = owner.line_items.loaded? ? owner.line_items.select { |li| li.variant_id == variant.id } : owner.line_items.where(variant_id: variant.id)

        candidates.detect do |line_item|
          Spree.cart_compare_line_items_service.call(order: owner, line_item: line_item, options: options).value
        end
      end
    end
  end
end
