module Spree
  module Cart
    class SetQuantity
      prepend Spree::ServiceModule::Base

      def call(order:, line_item:, quantity: nil)
        ActiveRecord::Base.transaction do
          run :change_item_quantity
          run Spree::Cart::Recalculate
        end
      end

      private

      def change_item_quantity(order:, line_item:, quantity: nil)
        return failure(I18n.t(:insufficient_stock_item_quantity, scope: 'spree')) unless line_item.update(quantity: quantity)
        success(order: order, line_item: line_item)
      end
    end
  end
end
