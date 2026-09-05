module Spree
  module Variants
    # The operator accepting a submitted offer, putting it on sale
    # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 3).
    class Approve < Spree::Workflow
      hooks :validate, :after_approve

      # @param variant [Spree::Variant]
      # @param reviewer [Spree.admin_user_class, nil] who decided
      # @param note [String, nil] shown to the seller
      # @param auto [Boolean] the store approves offers without review
      # @return [Spree::ServiceModule::Result] value is the variant
      def perform(variant:, reviewer: nil, note: nil, auto: false)
        super

        reject!(I18n.t('activerecord.errors.models.spree/variant.attributes.base.not_awaiting_review')) unless variant.proposed?

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_active
          step :close_submission
          run_hooks :after_approve
        end

        variant.publish_event('variant.approved')
        success(variant)
      end

      private

      def mark_active
        failure(variant) unless variant.update(status: 'active')
      end

      # An auto-approval says so on the row: a blank reviewer must read as
      # "this store does not review offers", never as a lost name.
      def close_submission
        Spree::ProductSubmissions::Close.call(
          product: variant.product,
          variant: variant,
          status: 'approved',
          reviewed_by: reviewer,
          review_note: note,
          metadata: auto ? { 'auto_approved' => true } : {}
        )
      end
    end
  end
end
