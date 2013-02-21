module Spree
  module Stock
    class Package
      ContentItem = Struct.new(:variant, :quantity, :status)

      attr_reader :stock_location, :order, :contents
      attr_accessor :shipping_rates

      def initialize(stock_location, order, contents=[])
        @stock_location = stock_location
        @order = order
        @contents = contents
        @shipping_rates = Array.new
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

      def find_item(variant, status=:on_hand)
        contents.select do |item|
          item.variant == variant &&
          item.status == status
        end.first
      end

      def quantity(status=nil)
        case status
        when :on_hand
          on_hand.sum { |item| item.quantity }
        when :backordered
          backordered.sum { |item| item.quantity }
        else
          contents.sum { |item| item.quantity }
        end
      end

      def empty?
        quantity == 0
      end

      def currency
        #TODO calculate from first variant?
      end

      def shipping_category
        #TODO return proper category?
      end

      def inspect
        contents.map do |content_item|
          "#{content_item.variant.name} #{content_item.quantity} #{content_item.status}"
        end.join('/')
      end
    end
  end
end
