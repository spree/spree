module Spree
  module Stock
    class Package
      ContentItem = Struct.new(:variant, :quantity, :state)

      attr_reader :stock_location, :order, :contents
      attr_accessor :shipping_rates

      def initialize(stock_location, order, contents=[])
        @stock_location = stock_location
        @order = order
        @contents = contents
        @shipping_rates = Array.new
      end

      def add(variant, quantity, state=:on_hand)
        contents << ContentItem.new(variant, quantity, state)
      end

      def weight
        contents.sum { |item| item.variant.weight * item.quantity }
      end

      def on_hand
        contents.select { |item| item.state == :on_hand }
      end

      def backordered
        contents.select { |item| item.state == :backordered }
      end

      def find_item(variant, state=:on_hand)
        contents.select do |item|
          item.variant == variant &&
          item.state == state
        end.first
      end

      def quantity(state=nil)
        case state
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

      def flattened
        flat = []
        contents.each do |item|
          item.quantity.times do
            flat << ContentItem.new(item.variant, 1, item.state)
          end
        end
        flat
      end

      def flattened=(flattened)
        contents.clear
        flattened.each do |item|
          current_item = find_item(item.variant, item.state)
          if current_item
            current_item.quantity += 1
          else
            add(item.variant, item.quantity, item.state)
          end
        end
      end

      def currency
        #TODO calculate from first variant?
      end

      def shipping_categories
        contents.map { |item| item.variant.shipping_category }.compact.uniq
      end

      def shipping_methods
        shipping_categories.map(&:shipping_methods).reduce(:&).to_a
      end

      def inspect
        out = "#{order} - "
        out << contents.map do |content_item|
          "#{content_item.variant.name} #{content_item.quantity} #{content_item.state}"
        end.join('/')
        out
      end

      def to_shipment
        shipment = Spree::Shipment.new
        shipment.order = order
        shipment.stock_location = stock_location
        shipment.shipping_rates = shipping_rates

        contents.each do |item|
          item.quantity.times do |n|
            unit = shipment.inventory_units.build
            unit.pending = true
            unit.order = order
            unit.variant = item.variant
            unit.state = item.state.to_s
          end
        end

        shipment
      end
    end
  end
end
