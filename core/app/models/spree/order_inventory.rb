module Spree
  class OrderInventory
    attr_accessor :order

    def initialize(order)
      @order = order
    end

    def verify(line_item, shipment=nil)
      return true unless order.completed?

      variant_units = inventory_units_for(line_item.variant)

      if variant_units.size < line_item.quantity
        #add

        quantity = line_item.quantity - variant_units.size

        shipment ||= order.shipments.detect { |shipment| (shipment.ready? || shipment.pending?) && shipment.include?(line_item.variant) }
        shipment ||= order.shipments.detect { |shipment| (shipment.ready? || shipment.pending?) && line_item.variant.stock_location_ids.include?(shipment.stock_location_id) }

        add_to_shipment(shipment,line_item.variant, quantity)

      elsif variant_units.size > line_item.quantity
        #remove

        quantity = variant_units.size - line_item.quantity

        order.shipments.each do |shipment|
          break if quantity == 0

          quantity -= remove_from_shipment(shipment, line_item.variant, quantity)
        end

      end
    end

    def inventory_units_for(variant)
      return [] unless order.completed?

      units = order.shipments.collect{|s| s.inventory_units.all}.flatten
      units.group_by(&:variant_id)[variant.id] || []
    end

    private

    def add_to_shipment(shipment, variant, quantity)
      #create inventory_units
      on_hand, back_order = shipment.stock_location.fill_status(variant, quantity)

      on_hand.times do
        shipment.inventory_units.create({:variant_id => variant.id,
                                          :state => 'on_hand'}, :without_protection => true)
      end

      back_order.times do
        shipment.inventory_units.create({:variant_id => variant.id,
                                         :state => 'backordered'}, :without_protection => true)
      end


      # adding to this shipment, and removing from stock_location
      shipment.stock_location.unstock variant, quantity, shipment

      # return quantity added
      quantity
    end

    def remove_from_shipment(shipment, variant, quantity)
      return 0 if quantity == 0 || shipment.shipped?

      shipment_units = shipment.inventory_units_for(variant)

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
