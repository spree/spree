module Spree
  module PromotionHandler
    class Page
      attr_reader :order, :path, :store

      def initialize(order, path)
        @order = order
        @store = order.store
        @path = path.gsub(/\A\//, '')
      end

      def activate
        if promotion&.eligible?(order)
          promotion.activate(order: order)
        end
      end

      private

      def promotion
        @promotion ||= store.promotions.active.find_by(path: path)
      end
    end
  end
end
