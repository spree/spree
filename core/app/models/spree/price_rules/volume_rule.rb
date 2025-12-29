module Spree
  module PriceRules
    class VolumeRule < Spree::PriceRule
      preference :min_quantity, :integer, default: 1
      preference :max_quantity, :integer
      preference :apply_to, :string, default: 'line_item'

      APPLY_TO_OPTIONS = %w[line_item cart_total].freeze

      validates :preferred_apply_to, inclusion: { in: APPLY_TO_OPTIONS }, allow_nil: true

      def applicable?(context)
        quantity = calculate_quantity(context)
        return false unless quantity

        return false if quantity < preferred_min_quantity
        return false if preferred_max_quantity && quantity > preferred_max_quantity

        true
      end

      def self.description
        'Apply pricing based on quantity purchased'
      end

      private

      def calculate_quantity(context)
        case preferred_apply_to
        when 'line_item'
          context.quantity
        when 'cart_total'
          context.order&.line_items&.find_by(variant: context.variant)&.quantity
        end
      end
    end
  end
end
