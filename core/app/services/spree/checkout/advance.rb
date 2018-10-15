module Spree
  module Checkout
    class Advance
      prepend Spree::ServiceModule::Base

      def call(order:)
        Spree::Checkout::Next.call(order: order) until cannot_make_transition?(order)
        success(order)
      end

      private

      def cannot_make_transition?(order)
        order.confirm? || order.complete? || order.errors.present?
      end
    end
  end
end
