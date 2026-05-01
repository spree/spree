module Spree
  module Cart
    class RemoveLineItem
      prepend Spree::ServiceModule::Base

      def call(order:, line_item:, options: nil)
        options ||= {}
        ActiveRecord::Base.transaction do
          order.line_items.destroy(line_item)

          # LineItem dependent: :destroy removes its own reservation row;
          # remaining items may need a fresh reservation pass when in checkout.
          if !order.cart? && !order.complete? && !order.canceled? && order.line_items.any?
            Spree::StockReservations::Reserve.call(order: order)
          end

          Spree.cart_recalculate_service.new.call(order: order,
                                                  line_item: line_item,
                                                  options: options)
        end
        success(line_item)
      end
    end
  end
end
