module Spree
  module Stock
    class ContentItem
      attr_accessor :inventory_unit, :state

      def initialize(inventory_unit, state = :on_hand)
        @inventory_unit = inventory_unit
        @state = state
      end

      with_options allow_nil: true do
        delegate :line_item,
                 :quantity,
                 :variant, to: :inventory_unit
        delegate :price, to: :variant
        delegate :dimension,
                 :volume,
                 :weight, to: :variant, prefix: true
      end

      def splittable_by_weight?
        quantity > 1 && variant_weight.present?
      end

      def weight
        variant_weight * quantity
      end

      def quantity=(value)
        @inventory_unit.quantity = value
      end

      def on_hand?
        state.to_s == 'on_hand'
      end

      def backordered?
        state.to_s == 'backordered'
      end

      def amount
        price * quantity
      end

      def volume
        variant_volume * quantity
      end

      def dimension
        variant_dimension * quantity
      end
    end
  end
end
