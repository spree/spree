module Spree
  module Checkout
    class Complete
      prepend Spree::ServiceModule::Base

      def call(order:)
        checkout_next_service.call(order: order) until cannot_make_transition?(order)

        if order.reload.complete?
          success(order)
        else
          failure(order)
        end
      end

      protected

      def cannot_make_transition?(order)
        order.complete? || order.errors.present?
      end

      def checkout_next_service
        Spree::Dependencies.checkout_next_service.constantize
      end
    end
  end
end
