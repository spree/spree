module Spree
  module Sellers
    # Turns down an applicant. Distinct from suspension: this one never traded,
    # so what they are told is that they were not admitted rather than that
    # they have been stopped.
    class Reject < Spree::Workflow
      hooks :validate, :after_reject

      # @param seller [Spree::Seller]
      # @param reason [String, nil] why, for the applicant and the audit trail
      # @param rejected_by [Object, nil] the staff member rejecting
      def perform(seller:, reason: nil, rejected_by: nil)
        super

        step :ensure_rejectable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_rejected
        end

        run_hooks :after_reject
        seller.publish_event('seller.rejected')
        success(seller.reload)
      end

      private

      # Only an applicant can be turned down. A trading seller is suspended,
      # which is reversible and says something different.
      def ensure_rejectable
        failure(seller, :already_rejected) if seller.rejected?
        failure(seller, :cannot_reject_approved) if seller.approved?

        return if seller.pending? || seller.invited? || seller.onboarding? || seller.ready_for_review?

        failure(seller, :not_rejectable)
      end

      def mark_rejected
        seller.update!(status: 'rejected')
        record_reason
      end

      def record_reason
        return if reason.blank?

        seller.update!(metadata: seller.metadata.to_h.merge('rejection_reason' => reason))
      end
    end
  end
end
