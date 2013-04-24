# Used by Prioritizer to adjust item quantities
# see prioritizer_spec for use cases
module Spree
  module Stock
    class Adjuster
      attr_accessor :variant, :need, :status

      def initialize(variant, quantity, status)
        @variant = variant
        @need = quantity
        @status = status
      end

      def adjust(item)
        if item.quantity >= need
          item.quantity = need
          @need = 0
        elsif item.quantity < need
          @need -= item.quantity
        end
      end

      def fulfilled?
        @need == 0
      end
    end
  end
end
