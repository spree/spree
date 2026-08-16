module Spree
  module Vendors
    # Turns down an applicant. Distinct from suspension: this one never traded,
    # so what they are told is that they were not admitted rather than that
    # they have been stopped.
    class Reject < Spree::Workflow
      hooks :validate, :after_reject

      # @param vendor [Spree::Vendor]
      # @param reason [String, nil] why, for the applicant and the audit trail
      # @param rejected_by [Object, nil] the staff member rejecting
      def perform(vendor:, reason: nil, rejected_by: nil)
        super

        step :ensure_rejectable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_rejected
        end

        run_hooks :after_reject
        vendor.publish_event('vendor.rejected')
        success(vendor.reload)
      end

      private

      # Only an applicant can be turned down. A trading vendor is suspended,
      # which is reversible and says something different.
      def ensure_rejectable
        failure(vendor, :already_rejected) if vendor.rejected?
        failure(vendor, :cannot_reject_approved) if vendor.approved?

        return if vendor.pending? || vendor.invited? || vendor.onboarding? || vendor.ready_for_review?

        failure(vendor, :not_rejectable)
      end

      def mark_rejected
        vendor.update!(status: 'rejected')
        record_reason
      end

      def record_reason
        return if reason.blank?

        vendor.update!(metadata: vendor.metadata.to_h.merge('rejection_reason' => reason))
      end
    end
  end
end
