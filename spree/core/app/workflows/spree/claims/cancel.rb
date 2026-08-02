module Spree
  module Claims
    class Cancel < Spree::Workflow
      hooks :validate, :after_cancel

      # @param claim [Spree::Claim]
      # @param reason [String, nil]
      def perform(claim:, reason: nil)
        super

        step :ensure_cancellable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_canceled
        end

        run_hooks :after_cancel
        claim.publish_event('claim.canceled')
        success(claim.reload)
      end

      private

      def ensure_cancellable
        return if claim.open? || claim.approved?

        failure(claim, :not_cancellable)
      end

      def mark_canceled
        memo = [claim.memo, reason].compact_blank.join("\n")
        claim.update!(status: 'canceled', canceled_at: Time.current, memo: memo.presence)
      end
    end
  end
end
