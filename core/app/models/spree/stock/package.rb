module Spree
  module Stock
    class Package
      ContentItem = Struct.new(:variant, :quantity, :status)

      attr_reader :stock_location, :order, :contents

      def initialize(stock_location, order, contents=[])
        @stock_location = stock_location
        @order = order
        @contents = contents
      end

      def add(variant, quantity, status=:on_hand)
        contents << ContentItem.new(variant, quantity, status)
      end

      def weight
        contents.sum { |item| item.variant.weight * item.quantity }
      end

      def on_hand
        contents.select { |item| item.status == :on_hand }
      end

      def backordered
        contents.select { |item| item.status == :backordered }
      end

      def quantity
        contents.sum { |item| item.quantity }
      end

      def inspect
        contents.map do |content_item|
          "#{content_item.variant.name} #{content_item.quantity} #{content_item.status}"
        end.join(',')
      end
    end
  end
end
