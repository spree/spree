module Spree
  module SellerRequirementSubmissions
    # The operator sends something back. The requirement returns to unmet and
    # the seller is told why — a rejection with no reason leaves them
    # resubmitting the same thing.
    class Reject < Spree::Workflow
      include Reviewable

      hooks :validate, :after_reject

      # @param submission [Spree::SellerRequirementSubmission]
      # @param reviewed_by [Object, nil] the staff member rejecting
      # @param review_note [String, nil] what was wrong with it
      def perform(submission:, reviewed_by: nil, review_note: nil)
        super

        step :ensure_rejectable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_rejected
        end

        run_hooks :after_reject
        submission.publish_event('seller_requirement_submission.rejected')
        success(submission.reload)
      end

      private

      # A waiver is the operator's own exception, and rejecting it in place
      # would overwrite who granted it and when. Withdrawing one is its own
      # act — the seller submits again, or the requirement changes — so this
      # refuses rather than quietly rewriting the record.
      def ensure_rejectable
        failure(submission, :already_rejected) if submission.rejected?
        failure(submission, :already_waived) if submission.waived?
      end

      def mark_rejected
        mark_reviewed('rejected')
      end
    end
  end
end
