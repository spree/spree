module Spree
  module Cart
    class Update
      prepend Spree::ServiceModule::Base

      def call(order:, params:)
        return failure(order) unless order.update(filter_order_items(order, params))

        order.line_items = order.line_items.select { |li| li.quantity > 0 }
        # Update totals, then check if the order is eligible for any cart promotions.
        # If we do not update first, then the item total will be wrong and ItemTotal
        # promotion rules would not be triggered.
        ActiveRecord::Base.transaction do
          order.update_with_updater!
          ::Spree::PromotionHandler::Cart.new(order).activate
          order.ensure_updated_shipments
          order.payments.store_credits.checkout.destroy_all
          order.update_with_updater!
        end
        success(order)
      end

      private

      def filter_order_items(order, params)
        line_items_attrs = params[:line_items_attributes]
        return params if line_items_attrs.nil?

        line_item_ids = order.line_item_ids.map(&:to_s)

        filtered =
          if line_items_attrs.is_a?(Array)
            line_items_attrs.select { |value| keep_line_item?(value, line_item_ids) }
          else
            # Preserve the id-only shortcut: a single unwrapped entry
            # like `{id: X, quantity: 0}` skips filtering entirely.
            return params if line_items_attrs[:id]

            line_items_attrs.each_with_object({}) do |(key, value), acc|
              acc[key] = value if keep_line_item?(value, line_item_ids)
            end
          end

        params.merge(line_items_attributes: filtered)
      end

      def keep_line_item?(value, line_item_ids)
        line_item_ids.include?(value[:id].to_s) || value[:variant_id].present?
      end
    end
  end
end
