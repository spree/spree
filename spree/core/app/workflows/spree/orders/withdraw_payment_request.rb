module Spree
  module Orders
    # Takes back a payment request: the draft returns to the merchant, out of
    # the storefront, and the payment sessions the buyer opened for it are
    # cancelled so none can still be paid. For a merchant who withdrew the
    # offer behind the draft, or wants to re-price it before asking again.
    #
    # A draft never requested is left as it is.
    class WithdrawPaymentRequest < Spree::Workflow
      hooks :validate, :after_withdraw_payment_request

      # @param order [Spree::Order]
      # @return [Spree::ServiceModule::Result] value is the order
      def perform(order:)
        super

        withdrawn = order.with_lock do
          step :ensure_draft
          run_hooks :validate

          next false if order.payment_requested_at.nil?

          order.update_columns(payment_requested_at: nil, updated_at: Time.current)
        end
        halt!(order.reload) unless withdrawn

        cancel_open_sessions
        run_hooks :after_withdraw_payment_request
        success(order.reload)
      end

      private

      # A placed order is paid for; there is no request left to take back.
      def ensure_draft
        failure(order, I18n.t('spree.order_payment_request_not_draft')) unless order.reload.standalone_draft?
      end

      def cancel_open_sessions
        return unless order.payment_sessions.unused.exists?

        Spree::Payments::CancelUnusedSessionsJob.perform_later(order.id)
      end
    end
  end
end
