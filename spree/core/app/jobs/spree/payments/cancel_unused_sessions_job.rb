module Spree
  module Payments
    # Cancels the payment sessions an order was placed without, so none of
    # them can still be paid. The cursor is the last session handled, so a
    # resume does not ask the provider again about sessions it already
    # refused.
    class CancelUnusedSessionsJob < Spree::BaseJob
      include ActiveJob::Continuable

      # Placement can run inside a webhook's transaction; enqueued before it
      # commits, the job could read the order before its sessions moved onto it.
      self.enqueue_after_transaction_commit = true

      def perform(order_id)
        # Outside the step on purpose: runs on every execution, resumes included.
        @order = Spree::Order.find_by(id: order_id)
        return if @order.nil?

        Spree::Current.store = @order.store

        step :cancel_sessions
      end

      private

      def cancel_sessions(step)
        payment_sessions = @order.payment_sessions.unused.order(:id)
        payment_sessions = payment_sessions.where(Spree::PaymentSession.arel_table[:id].gt(step.cursor)) if step.cursor

        payment_sessions.each do |payment_session|
          cancel(payment_session)
          step.set!(payment_session.id)
        end
      end

      def cancel(payment_session)
        payment_session.payment_method.cancel_payment_session(payment_session: payment_session)
      rescue StandardError => error
        # A refusal usually means the session was paid after all; retrying
        # cannot change that, and the order is placed either way.
        Rails.error.report(
          error,
          context: { payment_session_id: payment_session.id, order_id: @order.id },
          source: 'spree.payments.cancel_unused_sessions'
        )
      end
    end
  end
end
