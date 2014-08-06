module Spree
  class Exchange

    def initialize(order, reimbursement_items)
      @order = order
      @reimbursement_items = reimbursement_items
    end

    def description
      @reimbursement_items.map do |reimbursement_item|
        "#{reimbursement_item.variant.options_text} => #{reimbursement_item.exchange_variant.options_text}"
      end.join(" | ")
    end

    def display_amount
      Spree::Money.new @reimbursement_items.map(&:total).sum
    end

    def perform!
      shipments = Spree::Stock::Coordinator.new(@order, @reimbursement_items.map(&:build_exchange_inventory_unit)).shipments
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
