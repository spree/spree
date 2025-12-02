module Spree
  module Cart
    class RemoveOutOfStockItems
      prepend ::Spree::ServiceModule::Base

      def call(order:)
        @messages = []
        ActiveRecord::Base.transaction do
          line_items(order).each do |line_item|
            cart_remove_line_item_service.call(order: order, line_item: line_item) if !valid_status?(line_item) || !stock_available?(line_item)
          end
        end

        if @messages.any? # If any line item was removed, reload the order
          success([order.reload, @messages])
        else
          success([order, @messages])
        end
      end

      private

      def line_items(order)
        if order.line_items.empty?
          []
        elsif order.line_items.first.association_cached?(:variant) && order.line_items.first.variant.association_cached?(:product)
          # Don't include associations if it is already included, because it breaks other includes
          order.line_items
        else
          order.line_items.includes(variant: :product)
        end
      end

      def valid_status?(line_item)
        product = line_item.product
        if !product.active? || product.deleted? || product.discontinued? || line_item.variant.discontinued?
          @messages << Spree.t('cart_line_item.discontinued', li_name: line_item.name)
          return false
        end
        true
      end

      def stock_available?(line_item)
        if line_item.insufficient_stock?
          @messages << Spree.t('cart_line_item.out_of_stock', li_name: line_item.name)
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
