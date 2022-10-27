module Spree
  module Checkout
    class Advance
      prepend Spree::ServiceModule::Base

      def call(order:)
        Spree::Dependencies.checkout_next_service.constantize.call(order: order) until cannot_make_transition?(order)
        notify_order_stream(order: order) until cannot_make_transition?(order)
        success(order)
      end

      private

      def notify_order_stream(order:)
        Rails.configuration.event_store.publish(
          ::Checkout::Event::AdvanceOrder.new(data: { order: order.as_json }), stream_name: "order_#{order.number}"
        )

        success(order)
      end

      def cannot_make_transition?(order)
        order.confirm? || order.complete? || order.errors.present?
      end
    end
  end
end
