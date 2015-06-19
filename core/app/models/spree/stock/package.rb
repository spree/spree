module Spree
  module Stock
    class Package
      attr_reader :stock_location, :contents
      attr_accessor :shipping_rates

      def initialize(stock_location, contents=[])
        @stock_location = stock_location
        @contents = contents
        @shipping_rates = Array.new
      end

      def add(inventory_unit, state = :on_hand)
        contents << ContentItem.new(inventory_unit, state) unless find_item(inventory_unit)
      end

      def add_multiple(inventory_units, state = :on_hand)
        inventory_units.each { |inventory_unit| add(inventory_unit, state) }
      end

      def remove(inventory_unit)
        item = find_item(inventory_unit)
        @contents -= [item] if item
      end

      # Fix regression that removed package.order.
      # Find it dynamically through an inventory_unit.
      def order
        contents.detect {|item| !!item.try(:inventory_unit).try(:order) }.try(:inventory_unit).try(:order)
      end

      def weight
        contents.sum(&:weight)
      end

      def on_hand
        contents.select(&:on_hand?)
      end

      def backordered
        contents.select(&:backordered?)
      end

      def find_item(inventory_unit, state = nil)
        contents.detect do |item|
          item.inventory_unit == inventory_unit &&
            (!state || item.state.to_s == state.to_s)
        end
      end

      def quantity(state = nil)
        matched_contents = state.nil? ? contents : contents.select { |c| c.state.to_s == state.to_s }
        matched_contents.map(&:quantity).sum
      end

      def empty?
        quantity == 0
      end

      def currency
        order.currency
      end

      def shipping_categories
        contents.map { |item| item.variant.shipping_category }.compact.uniq
      end

      def shipping_methods
        shipping_categories.map(&:shipping_methods).reduce(:&).to_a
      end

      def inspect
        contents.map do |content_item|
          "#{content_item.variant.name} #{content_item.state}"
        end.join(' / ')
      end

      def to_shipment
        # At this point we should only have one content item per inventory unit
        # across the entire set of inventory units to be shipped, which has been
        # taken care of by the Prioritizer
        contents.each { |content_item| content_item.inventory_unit.state = content_item.state.to_s }

        Spree::Shipment.new(
          stock_location: stock_location,
          shipping_rates: shipping_rates,
          inventory_units: contents.map(&:inventory_unit)
        )
      end

      def contents_by_weight
        contents.sort { |x, y| y.weight <=> x.weight }
      end

      def volume
        contents.sum(&:volume)
      end

      def dimension
        contents.sum(&:dimension)
      end
    end
  end
end
