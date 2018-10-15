module Spree
  module Checkout
    class Update
      prepend Spree::ServiceModule::Base

      def call(order:, params:, request_env:)
        return success(order) if order.update_from_params(params, permitted_checkout_attributes, request_env)

        failure(order.errors)
      end

      private

      attr_reader :order, :params, :request_env
    end
  end
end
