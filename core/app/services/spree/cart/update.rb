module Spree
  module Cart
    class Update
      prepend Spree::ServiceModule::Base

      def call(order:, params:)
        return failure(false) unless order.update_attributes(filter_order_items(order, params))

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
        success(true)
      end

      private

      def filter_order_items(order, params)
        return params if params[:line_items_attributes].nil? || params[:line_items_attributes][:id]

        line_item_ids = order.line_items.pluck(:id)

        params[:line_items_attributes].each_pair do |id, value|
          unless line_item_ids.include?(value[:id].to_i) || value[:variant_id].present?
            params[:line_items_attributes].delete(id)
          end
        end
        params
      end
    end
  end
end
