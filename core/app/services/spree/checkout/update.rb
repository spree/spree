module Spree
  module Checkout
    class Update
      prepend Spree::ServiceModule::Base

      def call(order:, params:, permitted_attributes:, request_env:)
        return success(order) if order.update_from_params(params, permitted_attributes, request_env)

        failure(order)
      end
    end
  end
end
