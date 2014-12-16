module Spree
  class FinalizeShipment
    attr_reader :shipment

    def initialize(shipment)
      @shipment = shipment
    end

    ##
    # Finalize the inventory units of a shipment and decrement the stock
    # for the variants shipped.
    def execute!
      InventoryUnit.finalize_units!(shipment.inventory_units)
      shipment.unstock_manifest
    end
  end
end
