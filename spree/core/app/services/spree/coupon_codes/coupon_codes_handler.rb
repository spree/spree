module Spree
  module CouponCodes
    class CouponCodesHandler
      attr_reader :order, :codes

      def initialize(order:)
        @order = order
        @codes = Spree::CouponCode.where(order_id: order.id)
      end

      def use_all_codes
        return unless codes.any?

        promotion_ids = find_current_promotions_ids
        use_all_current(promotion_ids)
        clear_all_unused(promotion_ids)
      end

      private

      # Which promotions this checkout actually used.
      #
      # Read across the whole group when the order is one of several placed
      # together: the codes all sit on the first child, while the discount a
      # code bought may have landed on any of them. Asking only this order
      # would find no discount for a code that discounted a sibling, and
      # release a single-use code back for somebody to spend again.
      def find_current_promotions_ids
        scope = if order.respond_to?(:grouped?) && order.grouped?
                  Spree::Discount.where(order_id: order.order_group.orders.select(:id))
                else
                  order.discounts
                end

        scope.promotion.where.not(promotion_id: nil).distinct.pluck(:promotion_id)
      end

      def use_all_current(promotion_ids)
        codes.in_promotions(promotion_ids).update_all(state: 1)
      end

      def clear_all_unused(promotion_ids)
        codes.not_in_promotions(promotion_ids).update_all(order_id: nil)
      end
    end
  end
end
