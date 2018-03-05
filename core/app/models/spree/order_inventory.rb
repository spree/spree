module Spree
  class OrderInventory
    attr_accessor :order, :line_item, :variant

    def initialize(order, line_item)
      @order = order
      @line_item = line_item
      @variant = line_item.variant
    end

    delegate :inventory_units, to: :line_item

    # Only verify inventory for completed orders (as orders in frontend checkout
    # have inventory assigned via +order.create_proposed_shipment+) or when
    # shipment is explicitly passed
    #
    # In case shipment is passed the stock location should only unstock or
    # restock items if the order is completed. That is so because stock items
    # are always unstocked when the order is completed through +shipment.finalize+
    def verify(shipment = nil, is_updated: false)
      return unless order.completed? || shipment.present?

      units_count = inventory_units.reload.sum(&:quantity)
      line_item_changed = is_updated ? !line_item.saved_changes? : !line_item.changed?

      if units_count < line_item.quantity
        quantity = line_item.quantity - units_count

        shipment = determine_target_shipment unless shipment
        add_to_shipment(shipment, quantity)
      elsif (units_count > line_item.quantity) || (units_count == line_item.quantity && line_item_changed)
        remove(units_count, shipment)
      end
    end

    private

    def remove(units_count, target_shipment = nil)
      quantity = set_quantity_to_remove(units_count)

      if target_shipment.present?
        remove_from_shipment(target_shipment, quantity)
      else
        order.shipments.each do |shipment|
          break if quantity.zero?
          quantity -= remove_from_shipment(shipment, quantity)
        end
      end
    end

    def set_quantity_to_remove(units_count)
      if (units_count - line_item.quantity).zero?
        line_item.quantity
      else
        units_count - line_item.quantity
      end
    end

    # Returns either one of the shipment:
    #
    # first unshipped that already includes this variant
    # first unshipped that's leaving from a stock_location that stocks this variant
    def determine_target_shipment
      target_shipment = order.shipments.detect do |shipment|
        shipment.ready_or_pending? && shipment.include?(variant)
      end

      target_shipment || order.shipments.detect do |shipment|
        shipment.ready_or_pending? && variant.stock_location_ids.include?(shipment.stock_location_id)
      end
    end

    def add_to_shipment(shipment, quantity)
      if variant.should_track_inventory?
        on_hand, back_order = shipment.stock_location.fill_status(variant, quantity)

        shipment.set_up_inventory('on_hand', variant, order, line_item, on_hand)
        shipment.set_up_inventory('backordered', variant, order, line_item, back_order)
      else
        shipment.set_up_inventory('on_hand', variant, order, line_item, quantity)
      end

      # adding to this shipment, and removing from stock_location
      if order.completed?
        shipment.stock_location.unstock(variant, quantity, shipment)
      end

      quantity
    end

    def remove_from_shipment(shipment, quantity)
      return 0 if quantity.zero? || shipment.shipped?

      shipment_units = shipment.inventory_units_for_item(line_item, variant).reject(&:shipped?).sort_by(&:state)

      removed_quantity = 0
      removed_backordered = 0

      shipment_units.each do |inventory_unit|
        inventory_unit.quantity.times do
          break if removed_quantity == quantity
          if inventory_unit.quantity > 1
            inventory_unit.decrement(:quantity)
          else
            inventory_unit.destroy
          end
          removed_backordered += 1 if inventory_unit.backordered?
          removed_quantity += 1
        end
        inventory_unit.save! if inventory_unit.persisted?
      end

      shipment.destroy if shipment.inventory_units.sum(:quantity).zero?

      # removing this from shipment, and adding to stock_location
      if order.completed?
        current_on_hand = shipment.stock_location.count_on_hand(variant)

        if current_on_hand.negative? && current_on_hand.abs < removed_backordered
          shipment.stock_location.restock_backordered variant, current_on_hand.abs, shipment
        else
          shipment.stock_location.restock_backordered variant, removed_backordered, shipment
        end

        shipment.stock_location.restock variant, removed_quantity - removed_backordered, shipment
      end

      removed_quantity
    end
  end
end
