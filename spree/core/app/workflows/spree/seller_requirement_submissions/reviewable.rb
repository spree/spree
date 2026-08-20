module Spree
  module SellerRequirementSubmissions
    # Shared by the two operator decisions on a submission. Accepting and
    # rejecting differ in what they mean and what they announce, but both
    # record the same thing: who decided, when, and what they said.
    module Reviewable
      private

      def mark_reviewed(status)
        submission.update!(
          status: status,
          reviewed_by: reviewed_by,
          reviewed_at: Time.current,
          review_note: review_note.presence || submission.review_note
        )
      end
    end
  end
end
