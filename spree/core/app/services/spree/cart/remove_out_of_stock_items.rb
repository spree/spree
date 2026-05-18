module Spree
  module Cart
    class RemoveOutOfStockItems
      prepend ::Spree::ServiceModule::Base

      def call(order:)
        @messages = []
        @warnings = []

        return success([order, @messages, @warnings]) if order.item_count.zero? || order.line_items.none?

        line_items = order.line_items.includes(variant: [:product, :stock_locations, { stock_items: [:stock_location, :active_stock_reservations] }])

        ActiveRecord::Base.transaction do
          line_items.each do |line_item|
            cart_remove_line_item_service.call(order: order, line_item: line_item) if !valid_status?(line_item) || !stock_available?(line_item)
          end
        end

        if @messages.any? # If any line item was removed, reload the order
          success([order.reload, @messages, @warnings])
        else
          success([order, @messages, @warnings])
        end
      end

      private

      def valid_status?(line_item)
        product = line_item.product
        if !product.active? || product.deleted? || product.discontinued? || line_item.variant.discontinued?
          message = Spree.t('cart_line_item.discontinued', li_name: line_item.name)
          @messages << message
          @warnings << {
            code: 'line_item_removed',
            message: message,
            line_item_id: line_item.prefixed_id,
            variant_id: line_item.variant.prefixed_id
          }
          return false
        end
        true
      end

      def stock_available?(line_item)
        if line_item.insufficient_stock?
          message = Spree.t('cart_line_item.out_of_stock', li_name: line_item.name)
          @messages << message
          @warnings << {
            code: 'line_item_removed',
            message: message,
            line_item_id: line_item.prefixed_id,
            variant_id: line_item.variant.prefixed_id
          }
          return false
        end
        true
      end

      def cart_remove_line_item_service
        Spree.cart_remove_line_item_service
      end
    end
  end
end
