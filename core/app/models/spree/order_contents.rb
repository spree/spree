module Spree
  class OrderContents
    attr_accessor :order, :currency

    def initialize(order)
      @order = order
    end

    def add(variant, quantity = 1, options = {})
      line_item = add_to_line_item(variant, quantity, options)
      after_add_or_remove(line_item, options)
    end

    def remove(variant, quantity = 1, options = {})
      line_item = remove_from_line_item(variant, quantity, options)
      after_add_or_remove(line_item, options)
    end

    def update_cart(params)
      if order.update_attributes(filter_order_items(params))
        order.line_items = order.line_items.select { |li| li.quantity > 0 }
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
      def after_add_or_remove(line_item, options = {})
        reload_totals
        shipment = options[:shipment]
        shipment.present? ? shipment.update_amounts : order.ensure_updated_shipments
        PromotionHandler::Cart.new(order, line_item).activate
        ItemAdjustments.new(line_item).update
        reload_totals
        line_item
      end

      def filter_order_items(params)
        filtered_params = params.symbolize_keys
        return filtered_params if filtered_params[:line_items_attributes].nil? || filtered_params[:line_items_attributes][:id]

        line_item_ids = order.line_items.pluck(:id)

        params[:line_items_attributes].each_pair do |id, value|
          unless line_item_ids.include?(value[:id].to_i) || value[:variant_id].present?
            filtered_params[:line_items_attributes].delete(id)
          end
        end
        filtered_params
      end

      def order_updater
        @updater ||= OrderUpdater.new(order)
      end

      def reload_totals
        order_updater.update_item_count
        order_updater.update
        order.reload
      end

      def add_to_line_item(variant, quantity, options = {})
        line_item = grab_line_item_by_variant(variant, false, options)

        if line_item
          line_item.quantity += quantity.to_i
          line_item.currency = currency unless currency.nil?
        else
          opts = { currency: order.currency }.merge ActionController::Parameters.new(options).
                                              permit(PermittedAttributes.line_item_attributes)
          line_item = order.line_items.new(quantity: quantity,
                                            variant: variant,
                                            options: opts)
        end
        line_item.target_shipment = options[:shipment] if options.has_key? :shipment
        line_item.save!
        line_item
      end

      def remove_from_line_item(variant, quantity, options = {})
        line_item = grab_line_item_by_variant(variant, true, options)
        line_item.quantity -= quantity
        line_item.target_shipment= options[:shipment]

        if line_item.quantity == 0
          line_item.destroy
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
