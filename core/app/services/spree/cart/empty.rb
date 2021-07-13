module Spree
  module Cart
    class Empty
      prepend Spree::ServiceModule::Base

      def call(order:)
        order.empty! ? success(order) : failure(order)
      end
    end
  end
end
