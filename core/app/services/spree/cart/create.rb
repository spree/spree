module Spree
  module Cart
    class Create
      prepend Spree::ServiceModule::Base

      def call(user:, store:, currency:, public_metadata: {}, private_metadata: {}, order_params: {})
        order_params ||= {}

        # we cannot create an order without store
        return failure(:store_is_required) if store.nil?

        default_params = {
          user: user,
          currency: currency || store.default_currency,
          token: Spree::GenerateToken.new.call(Spree::Order),
          public_metadata: public_metadata.to_h,
          private_metadata: private_metadata.to_h
        }

        order = store.orders.create!(default_params.merge(order_params))
        notify_order_stream(user: user, store: store, order: order, public_metadata: public_metadata, private_metadata: private_metadata, order_params: {})
        success(order)
      end

      private

      def notify_order_stream(user:, store:, order:, public_metadata: {}, private_metadata: {}, order_params: {})
        Rails.configuration.event_store.publish(
          ::Checkout::Event::CreateOrder.new(data: { store: store, order: order.as_json, user: user.as_json }),
          stream_name: "customer_#{order.email}"
        )
      end
    end
  end
end
