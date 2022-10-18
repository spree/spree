module Spree
  module Cart
    class SetQuantity
      prepend Spree::ServiceModule::Base

      def call(order:, line_item:, quantity: nil)
        ActiveRecord::Base.transaction do
          run :change_item_quantity
          run :notify_order_stream
          run Spree::Dependencies.cart_recalculate_service.constantize
        end
      end

      private

      def notify_order_stream(order:, line_item:, quantity:)
        event_store.publish(
          EventStore::Publish::Cart::Update.new(data: { order: order.as_json, line_item: line_item, variant: line_item.variant, quantity: quantity }),
          stream_name: "order_#{order.number}_customer_#{order.user.id}" # check if usable with _customer
        )
      end

      def change_item_quantity(order:, line_item:, quantity: nil)
        return failure(line_item) unless line_item.update(quantity: quantity)

        success(order: order, line_item: line_item)
      end
    end
  end
end
