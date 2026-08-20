module Spree
  module SellerRequirementSubmissions
    # The operator excuses one seller from something the marketplace asks of
    # everyone — a seller who satisfied it off the marketplace, or one whose
    # circumstances the requirement was never written for.
    #
    # A waiver reads as met without pretending the seller did it, which is
    # the distinction that matters when someone reads the record later.
    class Waive < Spree::Workflow
      hooks :validate, :after_waive

      # @return [Spree::SellerRequirementSubmission]
      attr_reader :submission

      # @param seller [Spree::Seller]
      # @param requirement [Spree::SellerRequirement]
      # @param reviewed_by [Object, nil] the staff member waiving it
      # @param review_note [String, nil] why
      def perform(seller:, requirement:, reviewed_by: nil, review_note: nil)
        super

        step :ensure_waivable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :record_waiver
        end

        run_hooks :after_waive
        submission.publish_event('seller_requirement_submission.waived')
        success(submission)
      end

      private

      # Any active requirement can be waived, computed ones included: excusing
      # a seller from the terms or from a minimum catalog is exactly what a
      # waiver is for, and the base class honours it over the kind's own
      # reading. What cannot be waived is a requirement the store has switched
      # off — it is already asking nothing, so a waiver would only add a row
      # that means nothing (`Create` refuses inactive ones for the same
      # reason).
      def ensure_waivable
        failure(requirement, :requirement_store_mismatch) if requirement.store_id != seller.store_id
        failure(requirement, :requirement_inactive) unless requirement.active?
      end

      # A waiver is its own submission rather than an edit of whatever came
      # before: what the seller sent and what the operator decided are two
      # different acts, and the earlier one stays readable.
      def record_waiver
        @submission = seller.requirement_submissions.new(
          requirement: requirement,
          status: 'waived',
          reviewed_by: reviewed_by,
          reviewed_at: Time.current,
          review_note: review_note
        )

        failure(submission, submission.errors) unless submission.save
      end
    end
  end
end
