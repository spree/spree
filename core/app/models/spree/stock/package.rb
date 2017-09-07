module Spree
  module Stock
    class Package
      attr_reader :stock_location, :contents
      attr_accessor :shipping_rates

      def initialize(stock_location, contents = [])
        @stock_location = stock_location
        @contents = contents
        @shipping_rates = []
      end

      def add(inventory_unit, state = :on_hand)
        # Remove find_item check as already taken care by prioritizer
        contents << ContentItem.new(inventory_unit, state)
      end

      def add_multiple(inventory_units, state = :on_hand)
        inventory_units.each { |inventory_unit| add(inventory_unit, state) }
      end

      def remove(inventory_unit)
        item = find_item(inventory_unit)
        remove_item(item) if item
      end

      def remove_item(item)
        @contents -= [item]
      end

      # Fix regression that removed package.order.
      # Find it dynamically through an inventory_unit.
      def order
        contents.detect { |item| !!item.try(:inventory_unit).try(:order) }.try(:inventory_unit).try(:order)
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
        matched_contents.sum(&:quantity)
      end

      def empty?
        quantity.zero?
      end

      def currency
        order.currency
      end

      def shipping_categories
        Spree::ShippingCategory.joins(products: :variants_including_master).
          where(spree_variants: { id: variant_ids }).distinct
      end

      def shipping_methods
        shipping_categories.includes(:shipping_methods).map(&:shipping_methods).reduce(:&).to_a
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

      def volume
        contents.sum(&:volume)
      end

      def dimension
        contents.sum(&:dimension)
      end

      private

      def variant_ids
        contents.map { |item| item.inventory_unit.variant_id }.compact.uniq
      end
    end
  end
end
