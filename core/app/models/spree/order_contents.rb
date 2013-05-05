module Spree
  class OrderContents
    attr_accessor :order, :currency

    def initialize(order)
      @order = order
    end

    # Gets current line item for variant if exists
    # Adds variant qty to line_item
    # Returns the line_item created or updated
    def add(variant, quantity, currency = nil, shipment = nil)
      line_item = order.find_line_item_by_variant(variant)
      add_to_line_item(line_item, variant, quantity, currency, shipment)
    end

    # Gets current line item for variant
    # Updates item quantity or destroys it if quantity is 0
    # Returns the line_item updated or destroyed
    def remove(variant, quantity, shipment = nil)
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
        line_item.quantity += quantity
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
