module Spree
  module PriceRules
    class VolumeRule < Spree::PriceRule
      preference :min_quantity, :integer, default: 1
      preference :max_quantity, :integer, nullable: true

      def applicable?(context)
        return false unless context.quantity

        return false if context.quantity < preferred_min_quantity
        return false if preferred_max_quantity && context.quantity > preferred_max_quantity

        true
      end

      def self.description
        'Apply pricing based on quantity purchased'
      end

      # Quantity is a fact about the purchase, not the buyer, so this rule
      # still narrows a list its catalog has already matched on audience.
      def self.contextual?
        true
      end
    end
  end
end
