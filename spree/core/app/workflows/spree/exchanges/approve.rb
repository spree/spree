module Spree
  module Exchanges
    class Approve < Spree::Workflow
      hooks :validate, :after_approve

      # @param exchange [Spree::Exchange]
      # @param approver [Object, nil]
      def perform(exchange:, approver: nil)
        super

        step :ensure_approvable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_approved
        end

        run_hooks :after_approve
        exchange.publish_event('exchange.approved')
        success(exchange.reload)
      end

      private

      def ensure_approvable
        failure(exchange, :not_requested) unless exchange.requested?
      end

      def mark_approved
        exchange.update!(
          status: 'approved',
          approved_at: Time.current,
          created_by: exchange.created_by || approver
        )
      end
    end
  end
end
