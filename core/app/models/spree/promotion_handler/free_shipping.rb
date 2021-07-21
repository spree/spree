module Spree
  module PromotionHandler
    # Used for activating promotions with shipping rules
    class FreeShipping
      attr_reader :order, :order_promo_ids, :store
      attr_accessor :error, :success

      def initialize(order)
        @order = order
        @store = order.store
        @order_promo_ids = order.promotions.ids
      end

      def activate
        promotions.each do |promotion|
          next if promotion.code.present? && !order_promo_ids.include?(promotion.id)

          promotion.activate(order: order) if promotion.eligible?(order)
        end
      end

      private

      def promotions
        store.promotions.active.joins(:promotion_actions).
          where(Spree::PromotionAction.table_name => { type: 'Spree::Promotion::Actions::FreeShipping' }, path: nil).distinct
      end
    end
  end
end
