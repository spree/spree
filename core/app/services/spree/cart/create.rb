module Spree
  module Cart
    class Create
      prepend Spree::ServiceModule::Base

      def call(user:, store:, currency:, order_params: nil)
        order_params ||= {}

        # we cannot create an order without store
        return failure(:store_is_required) if store.nil?

        default_params = {
          user: user,
          currency: currency || store.default_currency,
          token: Spree::GenerateToken.new.call(Spree::Order)
        }

        order = store.orders.create!(default_params.merge(order_params))
        success(order)
      end
    end
  end
end
