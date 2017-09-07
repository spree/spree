module Spree
  module PromotionHandler
    # Used for activating promotions with shipping rules
    class FreeShipping
      attr_reader :order, :order_promo_ids
      attr_accessor :error, :success

      def initialize(order)
        @order = order
        @order_promo_ids = order.promotions.pluck(:id)
      end

      def activate
        promotions.each do |promotion|
          next if promotion.code.present? && !order_promo_ids.include?(promotion.id)

          promotion.activate(order: order) if promotion.eligible?(order)
        end
      end

      private

      def promotions
        Spree::Promotion.active.where(
          id: Spree::Promotion::Actions::FreeShipping.pluck(:promotion_id),
          path: nil
        )
      end
    end
  end
end
