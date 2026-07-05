module Spree
  module Orders
    # Admin-side order completion.
    #
    # Distinct from Spree::Carts::Complete (storefront checkout). Callers must
    # wrap invocation in Spree::Api::V3::OrderLock#with_order_lock — this
    # service does not lock the row itself.
    #
    # @param order [Spree::Order]
    # @param payment_pending [Boolean] if true, completes the order without
    #   processing payments. Order is placed but `payment_status` may be
    #   'balance_due'. Useful for B2B / invoice-later flows.
    # @param notify_customer [Boolean] if true, the customer receives the
    #   standard order confirmation email. Defaults to false — admin orders
    #   complete silently unless explicitly opted in.
    # @return [Spree::ServiceModule::Result]
    class Complete
      prepend Spree::ServiceModule::Base

      def call(order:, payment_pending: false, notify_customer: false)
        order.notify_customer = notify_customer

        return success(order) if order.completed?
        return failure(order, 'Order is canceled') if order.canceled?

        process_payments!(order) if order.payment_required? && !payment_pending

        return failure(order, order.errors.full_messages.to_sentence) if order.errors.any?

        advance_to_complete!(order)

        if order.reload.complete?
          success(order)
        else
          failure(order, order.errors.full_messages.to_sentence.presence || 'Could not complete order')
        end
      end

      private

      def process_payments!(order)
        return if order.payment_total >= order.total
        return if order.payments.valid.any?(&:completed?) && order.unprocessed_payments.empty?

        order.process_payments!
      end

      def advance_to_complete!(order)
        order.next until order.complete? || order.errors.present?
      end
    end
  end
end
