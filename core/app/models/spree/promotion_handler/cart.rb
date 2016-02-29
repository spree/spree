module Spree
  module PromotionHandler
    # Decides which promotion should be activated given the current order context
    #
    # By activated it doesn't necessarily mean that the order will have a
    # discount for every activated promotion. It means that the discount will be
    # created and might eventually become eligible. The intention here is to
    # reduce overhead. e.g. a promotion that requires item A to be eligible
    # shouldn't be eligible unless item A is added to the order.
    #
    # It can be used as a wrapper for custom handlers as well. Different
    # applications might have completely different requirements to make
    # the promotions system accurate and performant. Here they can plug custom
    # handler to activate promos as they wish once an item is added to cart
    class Cart
      attr_reader :line_item, :order
      attr_accessor :error, :success

      def initialize(order, line_item=nil)
        @order, @line_item = order, line_item
      end

      def activate
        promotions.each do |promotion|
          if (line_item && promotion.eligible?(line_item)) || promotion.eligible?(order)
            promotion.activate(line_item: line_item, order: order, promotion_code: promotion_code(promotion))
          end
        end
      end

      private

      # Reverting 715d4439f4f02a1d75b8adac74b77dd445b61908 here to add promotion_code join.
      # Might be good to combine these two.
      def promotions
        connected_order_promotions | sale_promotions
      end

      def connected_order_promotions
        Promotion.active.includes(:promotion_rules).
          joins(:order_promotions).
          where(spree_order_promotions: { order_id: order.id }).readonly(false).to_a
      end

      def sale_promotions
        promo_table = Promotion.arel_table
        code_table  = PromotionCode.arel_table

        promotion_code_join = promo_table.join(code_table, Arel::Nodes::OuterJoin).on(
          promo_table[:id].eq(code_table[:promotion_id])
        ).join_sources

        Promotion.active.includes(:promotion_rules).joins(promotion_code_join).
          where(code_table[:value].eq(nil).and(promo_table[:path].eq(nil))).distinct
      end

      def promotion_code(promotion)
        order_promotion = Spree::OrderPromotion.find_by(order: order, promotion: promotion)
        order_promotion.present? ? order_promotion.promotion_code : nil
      end
    end
  end
end
