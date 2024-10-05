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

      def find_current_promotions_ids
        order.all_adjustments.promotion.eligible.map { |a| a.source.try(:promotion_id) }.compact
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
