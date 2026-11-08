module Spree
  module Products
    # A seller submitting a product for the marketplace to review.
    #
    # The only way onto `proposed`: a seller never assigns a status, so this
    # is what separates "listed something" from "asked for it to go on sale"
    # (docs/plans/6.0-seller-product-submission.md).
    #
    # Chains straight into Approve when the store does not review listings,
    # mirroring how `auto_approve_sellers` chains seller onboarding.
    class Propose < Spree::Workflow
      hooks :validate, :after_propose

      # @param product [Spree::Product]
      # @param submitted_by [Spree.admin_user_class, nil] who asked
      # @param reason [String, nil] why a listing already on sale goes back to
      #   review — what changed on it. Recorded on the submission row. Without
      #   one, only a draft or a rejected product can be submitted.
      # @return [Spree::ServiceModule::Result] value is the product
      def perform(product:, submitted_by: nil, reason: nil)
        super

        # Only a listing that is being worked on can be submitted. Guarding
        # `active?` alone let an archived product through — and with
        # auto-approval on, a withdrawn listing went straight back on sale
        # without anybody reviewing it. Re-submitting one already in review
        # is equally meaningless. An active listing reopens review only when
        # the caller says what changed, which no seller-facing action does.
        unless product.draft? || product.rejected? || (reason.present? && product.active?)
          reject!(:cannot_propose, message: I18n.t('activerecord.errors.models.spree/product.attributes.base.cannot_propose'))
        end

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_proposed
          step :open_submission
          run_hooks :after_propose
        end

        product.publish_event('product.proposed')

        return Spree.product_approve_workflow.call(product: product, auto: true) if auto_approve?

        success(product)
      end

      private

      def mark_proposed
        failure(product) unless product.update(status: 'proposed')
      end

      # A resubmission opens a fresh row rather than reopening the decided
      # one: the trail is how many times this was asked for, and rewriting
      # the last answer would erase that.
      def open_submission
        product.submissions.create!(status: 'pending', submitted_by: submitted_by,
                                    metadata: reason.present? ? { 'reason' => reason } : {})
      end

      def auto_approve?
        product.store&.preferred_auto_approve_seller_products.present?
      end
    end
  end
end
