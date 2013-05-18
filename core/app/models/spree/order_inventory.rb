module Spree
  class OrderInventory
    attr_accessor :order

    def initialize(order)
      @order = order
    end

    # Only verify inventory for completed orders
    # as carts have inventory assigned via create_proposed_shipment methh
    #
    # or when shipment is explicitly passed
    def verify(line_item, shipment = nil)
      if order.completed? || shipment.present?

        variant_units = inventory_units_for(line_item.variant)

        if variant_units.size < line_item.quantity
          quantity = line_item.quantity - variant_units.size

          shipment = determine_target_shipment(line_item.variant) unless shipment
          add_to_shipment(shipment, line_item.variant, quantity)
        elsif variant_units.size > line_item.quantity
          remove(line_item, variant_units, shipment)
        end
      else
        true
      end
    end

    def inventory_units_for(variant)
      units = order.shipments.collect{|s| s.inventory_units.all}.flatten
      units.group_by(&:variant_id)[variant.id] || []
    end

    private
    def remove(line_item, variant_units, shipment = nil)
      quantity = variant_units.size - line_item.quantity

      if shipment.present?
        remove_from_shipment(shipment, line_item.variant, quantity)
      else
        order.shipments.each do |_shipment|
          break if quantity == 0
          quantity -= remove_from_shipment(_shipment, line_item.variant, quantity)
        end
      end
    end

    # Returns either one of the shipment:
    #
    # first unshipped that already includes this variant
    # first unshipped that's leaving from a stock_location that stocks this variant
    #
    def determine_target_shipment(variant)
      shipment = order.shipments.detect do |shipment|
        (shipment.ready? || shipment.pending?) && shipment.include?(variant)
      end

      shipment ||= order.shipments.detect do |_shipment|
        (_shipment.ready? || _shipment.pending?) && variant.stock_location_ids.include?(_shipment.stock_location_id)
      end
    end

    def add_to_shipment(shipment, variant, quantity)
      #create inventory_units
      on_hand, back_order = shipment.stock_location.fill_status(variant, quantity)

      on_hand.times do
        shipment.inventory_units.create({variant_id: variant.id,
                                          state: 'on_hand'}, without_protection: true)
      end

      back_order.times do
        shipment.inventory_units.create({variant_id: variant.id,
                                         state: 'backordered'}, without_protection: true)
      end


      # adding to this shipment, and removing from stock_location
      shipment.stock_location.unstock variant, quantity, shipment

      # return quantity added
      quantity
    end

    def remove_from_shipment(shipment, variant, quantity)
      return 0 if quantity == 0 || shipment.shipped?

      shipment_units = shipment.inventory_units_for(variant).reject do |variant_unit|
        variant_unit.state == 'shipped'
      end.sort_by(&:state)

      removed_quantity = 0

      shipment_units.each do |inventory_unit|
        break if removed_quantity == quantity
        inventory_unit.destroy
        removed_quantity += 1
      end

      if shipment.inventory_units.count == 0
        shipment.destroy
      end

      # removing this from shipment, and adding to stock_location
      shipment.stock_location.restock variant, removed_quantity, shipment

      # return quantity removed
      removed_quantity
    end
  end
end
