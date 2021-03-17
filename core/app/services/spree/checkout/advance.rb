module Spree
  module Checkout
    class Advance
      prepend Spree::ServiceModule::Base

      def call(order:)
        checkout_next_service.call(order: order) until cannot_make_transition?(order)
        success(order)
      end

      protected

      def cannot_make_transition?(order)
        order.confirm? || order.complete? || order.errors.present?
      end

      def checkout_next_service
        Spree::Dependencies.checkout_next_service.constantize
      end
    end
  end
end
