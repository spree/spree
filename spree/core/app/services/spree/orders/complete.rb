module Spree
  module Orders
    # Admin-side completion of a draft order, sharing finalize semantics with
    # cart checkout (idempotency, inventory finalization, reservation release).
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

        Spree::Dependencies.carts_complete_workflow.constantize.call(
          cart: order,
          payment_pending: payment_pending
        )
      end
    end
  end
end
