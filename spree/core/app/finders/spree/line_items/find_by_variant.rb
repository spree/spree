module Spree
  module LineItems
    class FindByVariant
      # @param owner [Spree::Cart, Spree::Order] the line-item owner
      # @param recipient [Hash, nil, Symbol] for a gift card variant, who the
      #   line is for: two recipients are two lines, and nil matches only a
      #   line without one. Left at :any, the first line holding the variant
      #   answers — what a removal or a by-variant quantity edit wants.
      def execute(owner: nil, cart: nil, order: nil, variant:, options: {}, recipient: :any)
        owner ||= cart || order
        candidates = owner.line_items.loaded? ? owner.line_items.select { |li| li.variant_id == variant.id } : owner.line_items.where(variant_id: variant.id).reorder(:id)
        line_item = if variant.gift_card? && recipient != :any
                      candidates.detect { |li| same_recipient?(li, recipient) }
                    else
                      candidates.first
                    end

        if line_item
          Spree.cart_compare_line_items_service.call(order: owner, line_item: line_item, options: options).value
        end

        line_item
      end

      private

      def same_recipient?(line_item, recipient)
        current = line_item.gift_card_recipient
        return recipient.blank? if current.nil?

        current.same_as?(recipient)
      end
    end
  end
end
