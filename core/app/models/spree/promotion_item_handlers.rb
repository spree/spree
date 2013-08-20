module Spree
  # Decides which promotion should be activated given the current order context
  #
  # By activated it doesn't necessarily mean that the order will have an
  # discount for every activated promotion. It means that the discount will be
  # created and might eventually become eligible. The intention here is to
  # reduce overhead. e.g. a promotion that requires item A to be eligible
  # shouldn't be eligible unless item A is added to the order.
  #
  # It can be used as a wrapper for custom handlers as well. Different
  # applications might have completely different requirements to make
  # the promotions system accurate and performant. Here they can plug custom
  # handler to activate promos as they wish once an item is added to cart
  class PromotionItemHandlers
    attr_reader :line_item, :order

    def initialize(line_item)
      @line_item, @order = line_item, line_item.order
    end

    def activate
      promotions.each do |promotion|
        if promotion.rules.empty?
          promotion.activate(line_item: line_item, order: order)
          next
        end

        rule_handlers.each do |handler|
          if handler.new(promotion: promotion, line_item: line_item).appliable?
            promotion.activate(line_item: line_item, order: order)
            next
          end
        end
      end
    end

    private
      # TODO Once we're sure this is worth it we should call:
      #
      #   Rails.application.config.spree.promotion_rule_handlers
      #
      # so that it's pluggable
      def rule_handlers
        [PromotionRuleHandler::Product]
      end

      # TODO Coupon code promotions should be removed here
      # we need a way to define promo activated when item is added to cart
      # (maybe still use the event_name attr in Promotion for that)
      def promotions
        Promotion.active.includes(:promotion_rules)
      end
  end

  # Tell if a given promotion is a valid candidate for the current order state
  module PromotionRuleHandler
    class Product
      attr_reader :promotion, :line_item

      def initialize(payload = {})
        @promotion = payload[:promotion]
        @line_item = payload[:line_item]
      end

      def appliable?
        promotion.product_ids.empty? || promotion.product_ids.include?(line_item.product.id)
      end
    end
  end
end
