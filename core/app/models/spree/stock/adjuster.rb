# Used by Prioritizer to adjust item quantities
# see prioritizer_spec for use cases
module Spree
  module Stock
    class Adjuster
      attr_accessor :inventory_unit, :status, :fulfilled, :package

      def initialize(inventory_unit, status, package=nil)
        @inventory_unit = inventory_unit
        @status = status
        @package = package
        @fulfilled = false
      end

      def adjust(package)
        if fulfilled?
          package.remove(inventory_unit)
        else
          self.fulfilled = true
        end
      end

      def reassign(status, package)
        @fulfilled = false
        @status = status
        @package = package
      end

      def fulfilled?
        fulfilled
      end
    end
  end
end
