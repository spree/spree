module Spree
  module Cart
    class Destroy
      prepend Spree::ServiceModule::Base

      def call(order:)
        run :check_if_can_be_destroyed
        run :cancel_shipments
        run :void_payments
        run :clear_addresses
        run :destroy_order
      end

      private

      def check_if_can_be_destroyed(order:)
        return failure(false, Spree.t(:cannot_be_destroyed)) unless order&.can_be_deleted?

        success(order: order)
      end

      def cancel_shipments(order:)
        order.shipments.each(&:cancel)

        success(order: order)
      end

      def void_payments(order:)
        order.payments.each(&:void)

        success(order: order)
      end

      def clear_addresses(order:)
        order.ship_address = nil unless order.ship_address&.can_be_deleted?
        order.bill_address = nil unless order.bill_address&.can_be_deleted?

        success(order: order)
      end

      def destroy_order(order:)
        destroyed_result = order.destroy

        return failure(false, Spree.t(:cannot_be_destroyed)) unless destroyed_result.present?

        success(order)
      end
    end
  end
end
