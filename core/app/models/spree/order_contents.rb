module Spree
  class OrderContents
    attr_accessor :order, :currency

    def initialize(order)
      @order = order
    end

    # Get current line item for variant if exists
    # Add variant qty to line_item
    def add(variant, quantity=1, currency=nil, shipment=nil)
      line_item = order.find_line_item_by_variant(variant)
      add_to_line_item(line_item, variant, quantity, currency, shipment)
    end

    # Get current line item for variant
    # Remove variant qty from line_item
    def remove(variant, quantity=1, shipment=nil)
      line_item = order.find_line_item_by_variant(variant)

      unless line_item
        raise ActiveRecord::RecordNotFound, "Line item not found for variant #{variant.sku}"
      end

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
