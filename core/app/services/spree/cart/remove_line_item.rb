module Spree
  module Cart
    class RemoveLineItem
      prepend Spree::ServiceModule::Base

      def call(order:, line_item:, options: nil)
        options ||= {}
        ActiveRecord::Base.transaction do
          line_item.destroy!
          Spree::Dependencies.cart_recalculate_service.constantize.new.call(order: order,
                                                                            line_item: line_item,
                                                                            options: options)
        end
        order.reload
        notify_order_stream(order: order, line_item: line_item)
        success(line_item)
      end

      private

      def notify_order_stream(order:, line_item:)
        event_store.publish(
          EventStore::Publish::Cart::Remove.new(data: { order: order.as_json, line_item: line_item.as_json }),
          stream_name: "order_#{order.number}_customer_#{order.user.id}" # check if usable with _customer
        )
      end
    end
  end
end
