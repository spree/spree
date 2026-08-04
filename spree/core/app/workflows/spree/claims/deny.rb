module Spree
  module Claims
    class Deny < Spree::Workflow
      hooks :validate, :after_deny

      # @param claim [Spree::Claim]
      # @param reason [String, nil] recorded on the claim for the customer
      def perform(claim:, reason: nil)
        super

        step :ensure_deniable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_denied
        end

        run_hooks :after_deny
        claim.publish_event('claim.denied')
        success(claim.reload)
      end

      private

      def ensure_deniable
        failure(claim, :not_open) unless claim.open?
      end

      def mark_denied
        memo = [claim.memo, reason].compact_blank.join("\n")
        claim.update!(status: 'denied', denied_at: Time.current, memo: memo.presence)
      end
    end
  end
end
