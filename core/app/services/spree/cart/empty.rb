module Spree
  module Cart
    class Empty
      prepend Spree::ServiceModule::Base

      def call(order:)
        run :check_if_can_be_empty
        run :empty_order
        run :notify_order_stream
      end

      private

      def notify_order_stream(order:)
        Rails.configuration.event_store.publish(
          ::Checkout::Event::EmptyCart.new(data: { order: order.as_json }),
          stream_name: "customer_#{order.email}"
        )

        success(order)
      end

      def check_if_can_be_empty(order:)
        return failure(Spree.t(:cannot_empty)) if order.nil? || order.completed?

        success(order: order)
      end

      def empty_order(order:)
        ActiveRecord::Base.transaction do
          order.line_items.destroy_all
          order.updater.update_item_count
          order.adjustments.destroy_all
          order.shipments.destroy_all
          order.state_changes.destroy_all
          order.order_promotions.destroy_all
          order.update_totals
          order.persist_totals
          order.restart_checkout_flow

          success(order: order)
        end
      end
    end
  end
end
