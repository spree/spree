module Spree
  module Stock
    class ContentItem
      attr_accessor :inventory_unit, :state

      def initialize(inventory_unit, state = :on_hand)
        @inventory_unit = inventory_unit
        @state = state
      end

      def variant
        inventory_unit.variant
      end

      def weight
        variant.weight * quantity
      end

      def line_item
        inventory_unit.line_item
      end

      def on_hand?
        state.to_s == "on_hand"
      end

      def backordered?
        state.to_s == "backordered"
      end

      def price
        variant.price
      end

      def amount
        price * quantity
      end

      def quantity
        # Since inventory units don't have a quantity,
        # make this always 1 for now, leaving ourselves
        # open to a different possibility in the future,
        # but this massively simplifies things for now
        1
      end

      def volume
        variant.volume * quantity
      end

      def dimension
        variant.dimension * quantity
      end
    end
  end
end
