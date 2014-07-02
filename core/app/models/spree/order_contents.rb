module Spree
  class OrderContents
    attr_accessor :order, :currency

    def initialize(order)
      @order = order
    end

    def add(variant, quantity = 1, currency = nil, shipment = nil)
      line_item = add_to_line_item(variant, quantity, currency, shipment)
      reload_totals
      activate_cart_promotions(line_item)
      ItemAdjustments.new(line_item).update
      reload_totals
      line_item
    end

    def remove(variant, quantity = 1, shipment = nil)
      line_item = remove_from_line_item(variant, quantity, shipment)
      reload_totals
      activate_cart_promotions(line_item)
      ItemAdjustments.new(line_item).update
      reload_totals
      line_item
    end

    def update_cart(params)
      if params[:line_items_attributes]
        order.line_items_attributes = params[:line_items_attributes]
        order.line_items = order.line_items.select {|li| li.quantity > 0 }
      end

      # Update totals, then check if the order is eligible for any cart promotions.
      # If we do not update first, then the item total will be wrong and ItemTotal
      # promotion rules would not be triggered.
      reload_totals
      PromotionHandler::Cart.new(order).activate
      order.promotions.each { |promotion| promotion.activate(order) }
      order.ensure_updated_shipments
      reload_totals

      order
    end

    def activate_cart_promotions(line_item)
      PromotionHandler::Cart.new(order, line_item).activate
    end

    private
      def order_updater
        @updater ||= OrderUpdater.new(order)
      end

      def reload_totals
        order_updater.update_item_count
        order_updater.update_item_total
        order_updater.update_adjustment_total

        order_updater.update_payment_state if order.completed?
        order_updater.update_totals

        order
      end

      def add_to_line_item(variant, quantity, currency=nil, shipment=nil)
        line_item = grab_line_item_by_variant(variant)

        if line_item
          line_item.target_shipment = shipment
          line_item.quantity += quantity.to_i
          line_item.currency = currency unless currency.nil?
        else
          line_item = order.line_items.build(quantity: quantity, variant: variant)
          line_item.tax_category = variant.tax_category
          line_item.target_shipment = shipment
          if currency
            line_item.currency = currency
            line_item.price    = variant.price_in(currency).amount
          else
            line_item.price    = variant.price
          end
        end

        line_item
      end

      def remove_from_line_item(variant, quantity, shipment=nil)
        line_item = grab_line_item_by_variant(variant, true)
        line_item.quantity -= quantity
        line_item.target_shipment= shipment

        if line_item.quantity == 0
          order.line_items.delete(line_item)
        else
          line_item.save
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
