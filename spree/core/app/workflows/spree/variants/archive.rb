module Spree
  module Variants
    # Takes an offer off sale for good
    # (docs/plans/6.0-seller-master-catalog-listings.md).
    class Archive < Spree::Workflow
      hooks :validate, :after_archive

      # @param variant [Spree::Variant]
      # @return [Spree::ServiceModule::Result] value is the variant
      def perform(variant:)
        super

        # Offers only. A first-party variant's availability is its product's
        # business, and taking one off sale through an offer workflow would
        # write a status nothing in the operator's catalog put there
        # (docs/plans/6.0-seller-master-catalog-listings.md).
        reject!(:not_an_offer, message: I18n.t('activerecord.errors.models.spree/variant.attributes.base.not_an_offer')) unless variant.offer?

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_archived
          step :withdraw_submission
          run_hooks :after_archive
        end

        variant.publish_event('variant.archived')
        success(variant)
      end

      private

      def mark_archived
        failure(variant) unless variant.update(status: 'archived')
      end

      def withdraw_submission
        return unless variant.latest_submission&.pending?

        Spree::ProductSubmissions::Close.call(product: variant.product, variant: variant, status: 'withdrawn')
      end
    end
  end
end
