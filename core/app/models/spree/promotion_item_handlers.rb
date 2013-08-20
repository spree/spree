module Spree
  class PromotionItemHandlers
    attr_reader :line_item, :order

    def initialize(line_item)
      @line_item, @order = line_item, line_item.order
    end

    def activate
      promotions.each do |promotion|
        if promotion.rules.empty? || eligible_item?(promotion)
          promotion.activate(line_item: line_item, order: order)
        end
      end
    end

    private
      # TODO Coupon code promotions should be removed here
      def promotions
        Promotion.active.includes(:promotion_rules)
      end

      def eligible_item?(promotion)
        promotion.product_ids.empty? || promotion.product_ids.include?(line_item.product.id)
      end
  end
end
