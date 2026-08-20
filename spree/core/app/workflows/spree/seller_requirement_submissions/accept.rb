module Spree
  module SellerRequirementSubmissions
    # The operator confirms what a seller submitted. The requirement is met
    # from here on, and the row is the record of who decided that.
    class Accept < Spree::Workflow
      include Reviewable

      hooks :validate, :after_accept

      # @param submission [Spree::SellerRequirementSubmission]
      # @param reviewed_by [Object, nil] the staff member accepting
      # @param review_note [String, nil]
      def perform(submission:, reviewed_by: nil, review_note: nil)
        super

        step :ensure_acceptable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_accepted
        end

        run_hooks :after_accept
        submission.publish_event('seller_requirement_submission.accepted')
        success(submission.reload)
      end

      private

      def ensure_acceptable
        failure(submission, :already_accepted) if submission.accepted?
        failure(submission, :already_waived) if submission.waived?
      end

      def mark_accepted
        mark_reviewed('accepted')
      end
    end
  end
end
