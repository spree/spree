# Used by Prioritizer to adjust item quantities
# see prioritizer_spec for use cases
module Spree
  module Stock
    class Adjuster
      attr_accessor :required_quantity, :received_quantity, :backorder_package,
                    :backorder_item

      def initialize(inventory_unit, status, package=nil)
        self.required_quantity = inventory_unit.line_item.quantity
        self.backorder_package = nil
        self.backorder_item    = nil
        self.received_quantity = 0
      end

      def adjust(package_to_adjust, item)
        if fulfilled?
          package_to_adjust.remove_item item
        elsif item.backordered?
          # We only use the first backorder item to fill backorders
          # as the items/packages are processed in priority order
          self.backorder_package = package_to_adjust if backorder_package.nil?
          self.backorder_item    = item if backorder_item.nil?
        else
          if item.quantity >= remaining_quantity
            item.quantity = remaining_quantity
          end
          self.received_quantity += item.quantity
          update_backorder
        end
      end

      def update_backorder
        return unless backorder_package.present?
        if fulfilled?
          backorder_package.remove_item  backorder_item
        elsif backorder_item.present?
          backorder_item.quantity = remaining_quantity
        end
      end

      def fulfilled?
        remaining_quantity == 0
      end

      def remaining_quantity
        required_quantity - received_quantity
      end
    end
  end
end
