module Spree
  class OrderInventory
    attr_accessor :order, :line_item, :variant

    def initialize(order, line_item)
      @order = order
      @line_item = line_item
      @variant = line_item.variant
    end

    # Only verify inventory for completed orders (as orders in frontend checkout
    # have inventory assigned via +order.create_proposed_shipment+) or when
    # shipment is explicitly passed
    #
    # In case shipment is passed the stock location should only unstock or
    # restock items if the order is completed. That is so because stock items
    # are always unstocked when the order is completed through +shipment.finalize+
    def verify(shipment = nil)
      if order.completed? || shipment.present?

        if inventory_units.size < line_item.quantity
          quantity = line_item.quantity - inventory_units.size

          shipment = determine_target_shipment unless shipment
          add_to_shipment(shipment, quantity)
        elsif inventory_units.size > line_item.quantity
          remove(inventory_units, shipment)
        end
      end
    end

    def inventory_units
      line_item.inventory_units
    end

    private
      def remove(item_units, shipment = nil)
        quantity = item_units.size - line_item.quantity

        if shipment.present?
          remove_from_shipment(shipment, quantity)
        else
          order.shipments.each do |shipment|
            break if quantity == 0
            quantity -= remove_from_shipment(shipment, quantity)
          end
        end
      end

      # Returns either one of the shipment:
      #
      # first unshipped that already includes this variant
      # first unshipped that's leaving from a stock_location that stocks this variant
      def determine_target_shipment
        shipment = order.shipments.detect do |shipment|
          shipment.ready_or_pending? && shipment.include?(variant)
        end

        shipment ||= order.shipments.detect do |shipment|
          shipment.ready_or_pending? && variant.stock_location_ids.include?(shipment.stock_location_id)
        end
      end

      def add_to_shipment(shipment, quantity)
        if variant.should_track_inventory?
          on_hand, back_order = shipment.stock_location.fill_status(variant, quantity)

          on_hand.times { shipment.set_up_inventory('on_hand', variant, line_item) }
          back_order.times { shipment.set_up_inventory('backordered', variant, line_item) }
        else
          quantity.times { shipment.set_up_inventory('on_hand', variant, line_item) }
        end

        # adding to this shipment, and removing from stock_location
        if order.completed?
          shipment.stock_location.unstock(variant, quantity, shipment)
        end

        quantity
      end

      def remove_from_shipment(shipment, quantity)
        return 0 if quantity == 0 || shipment.shipped?

        shipment_units = shipment.inventory_units_for_item(line_item, variant).reject do |variant_unit|
          variant_unit.state == 'shipped'
        end.sort_by(&:state)

        removed_quantity = 0

        shipment_units.each do |inventory_unit|
          break if removed_quantity == quantity
          inventory_unit.destroy
          removed_quantity += 1
        end

        shipment.destroy if shipment.inventory_units.count == 0

        # removing this from shipment, and adding to stock_location
        if order.completed?
          shipment.stock_location.restock variant, removed_quantity, shipment
        end

        removed_quantity
      end
  end
end
