module Spree
  module Checkout
    class Complete
      prepend Spree::ServiceModule::Base

      def call(order:)
        Spree::Dependencies.checkout_next_service.constantize.call(order: order) until cannot_make_transition?(order)

        if order.reload.complete?
          success(order)
        else
          failure(order)
        end
      end

      private

      def cannot_make_transition?(order)
        order.complete? || order.errors.present?
      end
    end
  end
end
