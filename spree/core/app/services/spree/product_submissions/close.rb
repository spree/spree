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
      # @param variant [Spree::Variant, nil] the offer being decided on, or
      #   nil when the decision is about the product itself
      #   (docs/plans/6.0-seller-master-catalog-listings.md)
      # @param reviewed_by [Spree.admin_user_class, nil] who decided
      # @param review_note [String, nil] shown to the seller
      # @param metadata [Hash] merged onto the row
      # @return [Spree::ServiceModule::Result] value is the submission
      def call(product:, status:, variant: nil, reviewed_by: nil, review_note: nil, metadata: {})
        # The head of the trail, and only if it is still open: scanning the
        # whole history for any pending row could settle a stale one from an
        # earlier cycle instead of the decision actually in front of us.
        #
        # The trail is the subject's own — an offer's rows and its product's
        # are separate histories about separate decisions.
        trail = variant ? variant.submissions : product.submissions
        latest = trail.latest_first.first
        submission = latest&.pending? ? latest : trail.new(status: 'pending', product: product)

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
