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

      def initialize(order, line_item = nil)
        @order = order
        @line_item = line_item
      end

      def activate
        promotions.each do |promotion|
          if (line_item && promotion.eligible?(line_item)) || promotion.eligible?(order)
            promotion.activate(line_item: line_item, order: order)
          else
            promotion.deactivate(line_item: line_item, order: order)
          end
        end
      end

      private

      def promotions
        Promotion.find_by_sql("#{order.promotions.active.to_sql} UNION #{Promotion.active.where(code: nil, path: nil).to_sql}")
      end
    end
  end
end
