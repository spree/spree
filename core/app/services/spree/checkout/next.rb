module Spree
  module Checkout
    class Next
      prepend Spree::ServiceModule::Base

      def call(order:)
        if order.next
          notify_order_stream(order: order)
          return success(order.reload)
        end

        failure(order)
      end

      private

      def notify_order_stream(order:)
        Rails.configuration.event_store.publish(
          ::Checkout::Event::NextOrderState.new(data: { order: order.as_json }), stream_name: "order_#{order.number}"
        )
      end
    end
  end
end
