module Spree
  module Claims
    class Approve < Spree::Workflow
      hooks :validate, :after_approve

      # @param claim [Spree::Claim]
      # @param approver [Object, nil]
      def perform(claim:, approver: nil)
        super

        step :ensure_approvable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_approved
        end

        run_hooks :after_approve
        claim.publish_event('claim.approved')
        success(claim.reload)
      end

      private

      def ensure_approvable
        failure(claim, :not_open) unless claim.open?
      end

      def mark_approved
        claim.update!(
          status: 'approved',
          approved_at: Time.current,
          created_by: claim.created_by || approver
        )
      end
    end
  end
end
