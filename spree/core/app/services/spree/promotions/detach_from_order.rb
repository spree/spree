module Spree
  module Promotions
    # Removes a promotion from a cart or order the way a shopper removing the
    # code does: the order promotion, held coupon code, discounts and items
    # the promotion added are removed, then totals are recalculated.
    class DetachFromOrder
      prepend Spree::ServiceModule::Base

      CREATE_LINE_ITEMS_ACTION_TYPES = %w[Spree::Promotion::Actions::CreateLineItems].freeze

      def call(order:, promotion:, clear_coupon_code: false)
        held_code = promotion.coupon_codes.held_by(order).first if promotion.multi_codes?
        clear_entered_coupon_code(order, held_code&.code || promotion.code) if clear_coupon_code

        # The order promotion has to go before line items are removed
        order.promotions.delete(promotion)

        if held_code
          held_code.remove_from_order
        else
          promotion.touch
        end

        order.discounts.where(promotion_action_id: promotion.actions.ids).destroy_all
        remove_promotion_line_items(order, promotion)
        order.recalculate_totals!

        success(order)
      end

      private

      # Carts keep the entered code, and recalculation would apply it again.
      # Callers that let the shopper be told the code went keep it.
      def clear_entered_coupon_code(order, code)
        return if code.blank? || !order.has_attribute?(:coupon_code)
        return unless order.read_attribute(:coupon_code).to_s.casecmp?(code)

        order.update_column(:coupon_code, nil)
      end

      def remove_promotion_line_items(order, promotion)
        action_ids = promotion.actions.where(type: CREATE_LINE_ITEMS_ACTION_TYPES).ids
        remove_service = order.is_a?(Spree::Cart) ? Spree.cart_remove_item_service : Spree.order_remove_item_service
        owner_key = order.is_a?(Spree::Cart) ? :cart : :order

        Spree::PromotionActionLineItem.where(promotion_action: action_ids).find_each do |item|
          next if order.find_line_item_by_variant(item.variant).blank?

          remove_service.call(owner_key => order, variant: item.variant, quantity: item.quantity)
        end
      end
    end
  end
end
