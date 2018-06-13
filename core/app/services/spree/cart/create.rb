module Spree
  module Cart
    class Create
      prepend Spree::ServiceModule::Base

      def call(user:, store:, order_params: nil)
        order_params ||= {}

        default_params = {
          user: user,
          store: store,
          currency: Spree::Config[:currency],
          token: GenerateToken.new.call(Spree::Order)
        }

        order = Spree::Order.create!(default_params.merge(order_params))
        success(order)
      end
    end
  end
end
