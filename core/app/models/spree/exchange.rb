module Spree
  class Exchange

    def initialize(order, return_items)
      @order = order
      @return_items = return_items
    end

    def description
      @return_items.map do |return_item|
        "#{return_item.variant.options_text} => #{return_item.exchange_variant.options_text}"
      end.join(" | ")
    end

    def display_amount
      Spree::Money.new @return_items.map(&:total).sum
    end

    def perform!
      shipments = Spree::Stock::Coordinator.new(@order, @return_items.map(&:build_exchange_inventory_unit)).shipments
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
