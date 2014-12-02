module Spree
  class OrderContents
    attr_accessor :order, :currency

    def initialize(order)
      @order = order
    end

    def add(variant, quantity = 1, currency = nil, shipment = nil)
      line_item = add_to_line_item(variant, quantity, currency, shipment)
      return line_item unless line_item.save
      reload_totals
      shipment ? shipment.update_amounts : order.ensure_updated_shipments
      PromotionHandler::Cart.new(order).activate
      reload_totals
      line_item
    end

    def remove(variant, quantity = 1, shipment = nil)
      line_item = remove_from_line_item(variant, quantity, shipment)
      reload_totals
      shipment ? shipment.update_amounts : order.ensure_updated_shipments
      PromotionHandler::Cart.new(order, line_item).activate
      reload_totals
      line_item
    end

    def update_cart(params)
      if order.update_attributes(params)
        order.line_items = order.line_items.select {|li| li.quantity > 0 }
        # Update totals, then check if the order is eligible for any cart promotions.
        # If we do not update first, then the item total will be wrong and ItemTotal
        # promotion rules would not be triggered.
        reload_totals
        PromotionHandler::Cart.new(order).activate
        order.ensure_updated_shipments
        reload_totals
        true
      else
        false
      end
    end

    private
      def order_updater
        @updater ||= OrderUpdater.new(order)
      end

      def reload_totals
        order_updater.update_item_count
        order_updater.update
      end

      def add_to_line_item(variant, quantity, currency, shipment)
        line_item = grab_line_item_by_variant(variant)
        line_item ||= order.line_items.new(quantity: 0, variant: variant)

        line_item.quantity += quantity

        line_item.target_shipment = shipment
        line_item.currency        = currency
        line_item.price           = variant.price_in(currency).amount

        line_item
      end

      def remove_from_line_item(variant, quantity, shipment=nil)
        line_item = grab_line_item_by_variant(variant, true)
        line_item.quantity -= quantity
        line_item.target_shipment= shipment

        if line_item.quantity == 0
          line_item.destroy
        else
          line_item.save!
        end

        line_item
      end

      def grab_line_item_by_variant(variant, raise_error = false)
        line_item = order.find_line_item_by_variant(variant)

        if !line_item.present? && raise_error
          raise ActiveRecord::RecordNotFound, "Line item not found for variant #{variant.sku}"
        end

        line_item
      end
  end
end
