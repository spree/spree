module Spree
  module Exchanges
    # Withdraws an exchange before the goods arrive. Once received, the
    # merchant holds the customer's items and must either fulfill the
    # replacement or refund.
    class Cancel < Spree::Workflow
      hooks :validate, :after_cancel

      # @param exchange [Spree::Exchange]
      # @param reason [String, nil]
      def perform(exchange:, reason: nil)
        super

        step :ensure_cancellable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_canceled
        end

        run_hooks :after_cancel
        exchange.publish_event('exchange.canceled')
        success(exchange.reload)
      end

      private

      def ensure_cancellable
        return if exchange.requested? || exchange.approved?

        failure(exchange, :not_cancellable)
      end

      def mark_canceled
        memo = [exchange.memo, reason].compact_blank.join("\n")
        exchange.update!(status: 'canceled', canceled_at: Time.current, memo: memo.presence)
      end
    end
  end
end
