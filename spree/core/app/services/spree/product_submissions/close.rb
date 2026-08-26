module Spree
  module ProductSubmissions
    # Settles the open row in a product's review trail
    # (docs/plans/6.0-seller-product-submission.md).
    #
    # Every exit from review comes through here — approved, rejected, or
    # withdrawn by the seller — so a `pending` row always means the
    # marketplace still owes an answer.
    #
    # Tier 1 (plain service) by design: it is one write with no hooks and no
    # external call, and it runs inside the deciding workflow's transaction.
    class Close
      prepend Spree::ServiceModule::Base

      # Products that predate the trail, or reached review before this shipped,
      # have nothing open. They get a row anyway rather than silently no-op:
      # the decision is what we are recording, and a missing submission is not
      # a reason to lose it.
      #
      # @param product [Spree::Product]
      # @param status [String] `approved`, `rejected` or `withdrawn`
      # @param reviewed_by [Spree.admin_user_class, nil] who decided
      # @param review_note [String, nil] shown to the seller
      # @param metadata [Hash] merged onto the row
      # @return [Spree::ServiceModule::Result] value is the submission
      def call(product:, status:, reviewed_by: nil, review_note: nil, metadata: {})
        submission = product.submissions.latest_first.detect(&:pending?) ||
                     product.submissions.new(status: 'pending')

        attributes = { status: status, reviewed_at: Time.current, reviewed_by: reviewed_by }
        # A decision with no note must not wipe the note the row already
        # carries: re-rejecting without one means "same reason as before".
        attributes[:review_note] = review_note if review_note.present?
        attributes[:metadata] = submission.metadata.to_h.merge(metadata) if metadata.present?

        submission.assign_attributes(attributes)
        submission.save!

        success(submission)
      end
    end
  end
end
