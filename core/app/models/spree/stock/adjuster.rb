# Used by Prioritizer to adjust item quantities
# see prioritizer_spec for use cases
module Spree
  module Stock
    class Adjuster
      attr_accessor :required_quantity, :received_quantity, :backorder_package,
                    :backorder_item

      def initialize(inventory_unit)
        self.required_quantity = inventory_unit.required_quantity
        self.backorder_package = nil
        self.backorder_item = nil
        self.received_quantity = 0
      end

      def adjust(package_to_adjust, item)
        if fulfilled?
          package_to_adjust.remove_item item
        elsif item.backordered?
          # We only use the first backorder item to fill backorders
          # as the items/packages are processed in priority order
          if backorder_package.nil?
            self.backorder_package = package_to_adjust
            self.backorder_item = item
          else
            package_to_adjust.remove_item item
          end
        else
          if item.quantity >= remaining_quantity
            item.quantity = remaining_quantity
          end
          self.received_quantity += item.quantity
          update_backorder
        end
      end

      def update_backorder
        return if backorder_package.nil?

        if fulfilled?
          backorder_package.remove_item backorder_item
        elsif backorder_item.present?
          backorder_item.quantity = remaining_quantity
        end
      end

      def fulfilled?
        remaining_quantity.zero?
      end

      def remaining_quantity
        required_quantity - received_quantity
      end
    end
  end
end
