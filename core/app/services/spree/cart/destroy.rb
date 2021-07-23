module Spree
  module Cart
    class Destroy
      prepend Spree::ServiceModule::Base

      def call(order:)
        run :check_if_can_be_destroyed
        run :destroy_order
      end

      private

      def check_if_can_be_destroyed(order:)
        return failure(Spree.t(:cannot_be_destroyed)) unless order&.can_be_destroyed?

        success(order: order)
      end

      def destroy_order(order:)
        order.destroy

        success(order)
      end
    end
  end
end
