module Spree
  class OrderContents
    attr_accessor :order, :currency

    def initialize(order)
      @order = order
    end

    def add(variant, quantity, currency=nil, shipment=nil)
      #get current line item for variant if exists
      line_item = order.find_line_item_by_variant(variant)

      #add variant qty to line_item
      add_to_line_item(line_item, variant, quantity, currency, shipment)
    end

    def remove(variant, quantity, shipment=nil)
      #get current line item for variant
      line_item = order.find_line_item_by_variant(variant)

      #TODO raise exception if line_item is nil

      #remove variant qty from line_item
      remove_from_line_item(line_item, variant, quantity, shipment)
    end

    private

    def add_to_line_item(line_item, variant, quantity, currency=nil, shipment=nil)
      if line_item
        line_item.target_shipment = shipment
        line_item.quantity += quantity.to_i
        line_item.currency = currency unless currency.nil?
        line_item.save
      else
        line_item = LineItem.new(quantity: quantity)
        line_item.target_shipment = shipment
        line_item.variant = variant
        if currency
          line_item.currency = currency unless currency.nil?
          line_item.price    = variant.price_in(currency).amount
        else
          line_item.price    = variant.price
        end
        order.line_items << line_item
        line_item
      end

      order.reload
      line_item
    end

    def remove_from_line_item(line_item, variant, quantity, shipment=nil)
      line_item.quantity += -quantity
      line_item.target_shipment= shipment

      if line_item.quantity == 0
        Spree::OrderInventory.new(order).verify(line_item, shipment)
        line_item.destroy
      else
        line_item.save!
      end

      order.reload
      line_item
    end

  end
end
