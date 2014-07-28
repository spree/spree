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
            promotion.activate(line_item: line_item, order: order)
          end
        end
      end

      private
        def promotions
          promo_table = Promotion.arel_table
          join_table = Arel::Table.new(:spree_orders_promotions)

          join_condition = promo_table.join(join_table, Arel::Nodes::OuterJoin).on(
            promo_table[:id].eq(join_table[:promotion_id])
          ).join_sources

          Promotion.active.includes(:promotion_rules).
            joins(join_condition).
            where(
              promo_table[:code].eq(nil).and(
                promo_table[:path].eq(nil)
              ).or(join_table[:order_id].eq(order.id))
            ).distinct
        end
    end
  end
end
