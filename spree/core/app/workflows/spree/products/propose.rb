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
      # @return [Spree::ServiceModule::Result] value is the product
      def perform(product:)
        super

        # Only a listing that is being worked on can be submitted. Guarding
        # `active?` alone let an archived product through — and with
        # auto-approval on, a withdrawn listing went straight back on sale
        # without anybody reviewing it. Re-submitting one already in review
        # is equally meaningless.
        unless product.draft? || product.rejected?
          reject!(Spree.t('activerecord.errors.models.spree/product.attributes.base.cannot_propose'))
        end

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_proposed
          run_hooks :after_propose
        end

        product.publish_event('product.proposed')

        return Spree.product_approve_workflow.call(product: product) if auto_approve?

        success(product)
      end

      private

      def mark_proposed
        failure(product) unless product.update(status: 'proposed')
      end

      def auto_approve?
        product.store&.preferred_auto_approve_seller_products.present?
      end
    end
  end
end
