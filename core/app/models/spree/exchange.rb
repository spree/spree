module Spree
  class Exchange
    class UnableToCreateShipments < StandardError; end

    def initialize(order, reimbursement_objects)
      @order = order
      @reimbursement_objects = reimbursement_objects
    end

    def description
      @reimbursement_objects.map do |reimbursement_object|
        "#{reimbursement_object.variant.options_text} => #{reimbursement_object.exchange_variant.options_text}"
      end.join(" | ")
    end

    def display_amount
      Spree::Money.new @reimbursement_objects.map(&:total).sum
    end

    def perform!
      shipments = Spree::Stock::Coordinator.new(@order, @reimbursement_objects.map(&:build_exchange_inventory_unit)).shipments
      if shipments.flat_map(&:inventory_units).size != @reimbursement_objects.size
        raise UnableToCreateShipments.new("Could not generate shipments for all items. Out of stock?")
      end
      @order.shipments += shipments
      @order.save!
      shipments.each do |shipment|
        shipment.update!(@order)
        shipment.finalize!
      end
    end

    def to_key
      nil
    end

    def self.param_key
      "spree_exchange"
    end

    def self.model_name
      Spree::Exchange
    end

  end
end
