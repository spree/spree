module Spree
  module Variants
    # The operator turning a submitted offer down.
    #
    # The reason lands on the offer's submission row, never on the variant:
    # a seller writes their own row's metadata, and an operator's decision
    # must not be erasable by its subject
    # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 3).
    class Reject < Spree::Workflow
      hooks :validate, :after_reject

      # @param variant [Spree::Variant]
      # @param reason [String, nil] shown to the seller
      # @param reviewer [Spree.admin_user_class, nil] who decided
      # @return [Spree::ServiceModule::Result] value is the variant
      def perform(variant:, reason: nil, reviewer: nil)
        super

        # Already rejected counts: correcting the note you gave a seller is
        # not a second decision. Anything else has not been submitted.
        unless variant.proposed? || variant.rejected?
          reject!(I18n.t('activerecord.errors.models.spree/variant.attributes.base.not_awaiting_review'))
        end

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_rejected
          step :close_submission
          run_hooks :after_reject
        end

        variant.publish_event('variant.rejected')
        success(variant)
      end

      private

      def mark_rejected
        failure(variant) unless variant.update(status: 'rejected')
      end

      def close_submission
        Spree::ProductSubmissions::Close.call(
          product: variant.product,
          variant: variant,
          status: 'rejected',
          reviewed_by: reviewer,
          review_note: reason
        )
      end
    end
  end
end
