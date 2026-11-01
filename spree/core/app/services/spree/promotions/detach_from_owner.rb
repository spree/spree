module Spree
  module Promotions
    # Removes a promotion from a cart or an order the way a shopper removing the
    # code does: the order promotion, held coupon code, discounts and items
    # the promotion added are removed, then totals are recalculated.
    #
    # @example Removing a promotion from a cart
    #   Spree::Promotions::DetachFromOwner.call(owner: cart, promotion: promotion)
    class DetachFromOwner
      prepend Spree::ServiceModule::Base

      # Action types whose line items are removed along with the promotion.
      CREATE_LINE_ITEMS_ACTION_TYPES = %w[Spree::Promotion::Actions::CreateLineItems].freeze

      # @param owner [Spree::Cart, Spree::Order] the cart or order holding the promotion
      # @param promotion [Spree::Promotion] the promotion to remove
      # @param clear_coupon_code [Boolean] also clear the code the shopper entered on the
      #   owner, so recalculating does not apply the promotion again. Leave it off when the
      #   shopper should be told the code was lost.
      # @return [Spree::ServiceModule::Result] success, holding the owner
      def call(owner:, promotion:, clear_coupon_code: false)
        held_code = promotion.coupon_codes.held_by(owner).first if promotion.multi_codes?
        clear_entered_coupon_code(owner, held_code&.code || promotion.code) if clear_coupon_code

        # The order promotion has to go before line items are removed
        owner.promotions.delete(promotion)

        if held_code
          held_code.remove_from_order
        else
          promotion.touch
        end

        owner.discounts.where(promotion_action_id: promotion.actions.ids).destroy_all
        remove_promotion_line_items(owner, promotion)
        owner.recalculate_totals!

        success(owner)
      end

      private

      # Carts keep the entered code, and recalculation would apply it again.
      # Callers that let the shopper be told the code went keep it.
      def clear_entered_coupon_code(owner, code)
        return if code.blank? || !owner.has_attribute?(:coupon_code)
        return unless owner.read_attribute(:coupon_code).to_s.casecmp?(code)

        owner.update_column(:coupon_code, nil)
      end

      # Removes the line items a promotion's create-line-items actions added.
      def remove_promotion_line_items(owner, promotion)
        action_ids = promotion.actions.where(type: CREATE_LINE_ITEMS_ACTION_TYPES).ids
        remove_service = owner.is_a?(Spree::Cart) ? Spree.cart_remove_item_service : Spree.order_remove_item_service
        owner_key = owner.is_a?(Spree::Cart) ? :cart : :order

        Spree::PromotionActionLineItem.where(promotion_action: action_ids).find_each do |item|
          next if owner.find_line_item_by_variant(item.variant).blank?

          # The promotion is still active here, so recalculating would add its items back;
          # other promotions are still re-evaluated.
          options = owner.is_a?(Spree::Cart) ? { excluded_promotion_ids: [promotion.id] } : {}
          remove_service.call(owner_key => owner, variant: item.variant, quantity: item.quantity, options: options)
        end
      end
    end
  end
end
