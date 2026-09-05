module Spree
  module Products
    # The operator turning a submitted product down.
    #
    # The reason lands on the product's submission row, never on the product
    # itself: a seller can write their own product's metadata, and an
    # operator's decision must not be erasable by its subject
    # (docs/plans/6.0-seller-product-submission.md).
    class Reject < Spree::Workflow
      hooks :validate, :after_reject

      # @param product [Spree::Product]
      # @param reason [String, nil] shown to the seller
      # @param reviewer [Spree.admin_user_class, nil] who decided
      # @return [Spree::ServiceModule::Result] value is the product
      def perform(product:, reason: nil, reviewer: nil)
        super

        # Already rejected counts: correcting the note you gave a seller is
        # not a second decision, and the panel offers exactly that. Anything
        # else has not been submitted, so there is nothing to turn down.
        unless product.proposed? || product.rejected?
          reject!(:not_awaiting_review, message: I18n.t('activerecord.errors.models.spree/product.attributes.base.not_awaiting_review'))
        end

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_rejected
          step :close_submission
          run_hooks :after_reject
        end

        product.publish_event('product.rejected')
        success(product)
      end

      private

      def mark_rejected
        failure(product) unless product.update(status: 'rejected')
      end

      def close_submission
        Spree::ProductSubmissions::Close.call(
          product: product,
          status: 'rejected',
          reviewed_by: reviewer,
          review_note: reason
        )
      end
    end
  end
end
