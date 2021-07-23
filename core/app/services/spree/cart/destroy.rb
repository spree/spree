module Spree
  module Cart
    class Destroy
      prepend Spree::ServiceModule::Base

      def call(order:)
        run :check_if_can_be_empty
        run :destroy_order
      end

      private

      def check_if_can_be_empty(order:)
        return failure(Spree.t(:no_order_given)) if order.nil?
        return failure(order, Spree.t(:cannot_empty_completed_order)) if order.completed?

        success(order: order)
      end

      def destroy_order(order:)
        order.destroy

        success(order)
      end
    end
  end
end
