# Used by Prioritizer to adjust item quantities
# see prioritizer_spec for use cases
module Spree
  module Stock
    class Adjuster
      attr_accessor :inventory_unit, :status, :fulfilled

      def initialize(inventory_unit, status)
        @inventory_unit = inventory_unit
        @status = status
        @fulfilled = false
      end

      def adjust(package)
        if fulfilled?
          package.remove(inventory_unit)
        else
          self.fulfilled = true
        end
      end

      def fulfilled?
        fulfilled
      end
    end
  end
end
