module Spree
  class OrderContents
    attr_accessor :order, :currency

    def initialize(order)
      @order = order
    end

    def add(variant, quantity = 1, options = {})
      timestamp = Time.current
      line_item = add_to_line_item(variant, quantity, options)
      options[:line_item_created] = true if timestamp <= line_item.created_at
      after_add_or_remove(line_item, options)
    end

    def remove(variant, quantity = 1, options = {})
      line_item = remove_from_line_item(variant, quantity, options)
      after_add_or_remove(line_item, options)
    end

    def remove_line_item(line_item, options = {})
      line_item.destroy!
      after_add_or_remove(line_item, options)
    end

    def update_cart(params)
      if order.update_attributes(filter_order_items(params))
        order.line_items = order.line_items.select { |li| li.quantity > 0 }
        # Update totals, then check if the order is eligible for any cart promotions.
        # If we do not update first, then the item total will be wrong and ItemTotal
        # promotion rules would not be triggered.
        persist_totals
        PromotionHandler::Cart.new(order).activate
        order.ensure_updated_shipments
        order.payments.store_credits.checkout.destroy_all
        persist_totals
        true
      else
        false
      end
    end

    private

    def after_add_or_remove(line_item, options = {})
      order.payments.store_credits.checkout.destroy_all
      persist_totals
      shipment = options[:shipment]
      if shipment.present?
        # ADMIN END SHIPMENT RATE FIX
        # refresh shipments to ensure correct shipment amount is calculated when using price sack calculator
        # for calculating shipment rates.
        # Currently shipment rate is calculated on previous order total instead of current order total when updating a shipment from admin end.
        order.refresh_shipment_rates(ShippingMethod::DISPLAY_ON_BACK_END)
        shipment.update_amounts
      else
        order.ensure_updated_shipments
      end
      PromotionHandler::Cart.new(order, line_item).activate
      Adjustable::AdjustmentsUpdater.update(line_item)
      TaxRate.adjust(order, [line_item]) if options[:line_item_created]
      persist_totals
      line_item
    end

    def filter_order_items(params)
      return params if params[:line_items_attributes].nil? || params[:line_items_attributes][:id]

      line_item_ids = order.line_items.pluck(:id)

      params[:line_items_attributes].each_pair do |id, value|
        unless line_item_ids.include?(value[:id].to_i) || value[:variant_id].present?
          params[:line_items_attributes].delete(id)
        end
      end
      params
    end

    def order_updater
      @updater ||= OrderUpdater.new(order)
    end

    def persist_totals
      order_updater.update_item_count
      order_updater.update
    end

    def add_to_line_item(variant, quantity, options = {})
      line_item = grab_line_item_by_variant(variant, false, options)

      if line_item
        line_item.quantity += quantity.to_i
        line_item.currency = currency unless currency.nil?
      else
        options_params = options.is_a?(ActionController::Parameters) ? options : ActionController::Parameters.new(options.to_h)
        opts = options_params.
               permit(PermittedAttributes.line_item_attributes).to_h.
               merge(currency: order.currency)

        line_item = order.line_items.new(quantity: quantity,
                                         variant: variant,
                                         options: opts)
      end
      line_item.target_shipment = options[:shipment] if options.key? :shipment
      line_item.save!
      line_item
    end

    def remove_from_line_item(variant, quantity, options = {})
      line_item = grab_line_item_by_variant(variant, true, options)
      line_item.quantity -= quantity
      line_item.target_shipment = options[:shipment]

      if line_item.quantity.zero?
        order.line_items.destroy(line_item)
      else
        line_item.save!
      end

      line_item
    end

    def grab_line_item_by_variant(variant, raise_error = false, options = {})
      line_item = order.find_line_item_by_variant(variant, options)

      if !line_item.present? && raise_error
        raise ActiveRecord::RecordNotFound, "Line item not found for variant #{variant.sku}"
      end

      line_item
    end
  end
end
