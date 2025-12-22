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
        order.all_adjustments.promotion.eligible.joins("INNER JOIN #{Spree::PromotionAction.table_name} ON #{Spree::PromotionAction.table_name}.id = #{Spree::Adjustment.table_name}.source_id").
          pluck("#{Spree::PromotionAction.table_name}.promotion_id").compact.uniq
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
