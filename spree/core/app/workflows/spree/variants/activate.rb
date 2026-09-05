module Spree
  module Variants
    # The operator putting one of their own variants on sale.
    #
    # Separate from Approve, which closes a review a seller opened: this one
    # answers to nobody and is what the operator's own catalog uses to move a
    # row out of draft (docs/plans/6.0-seller-master-catalog-listings.md).
    class Activate < Spree::Workflow
      hooks :validate, :after_activate

      # @param variant [Spree::Variant]
      # @return [Spree::ServiceModule::Result] value is the variant
      def perform(variant:)
        super

        # An offer reaches `active` only through Approve — otherwise an
        # operator could put a seller's row on sale while recording no
        # decision and closing no submission.
        reject!(I18n.t('activerecord.errors.models.spree/variant.attributes.base.offer_needs_review')) if variant.offer?

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_active
          run_hooks :after_activate
        end

        variant.publish_event('variant.activated')
        success(variant)
      end

      private

      def mark_active
        failure(variant) unless variant.update(status: 'active')
      end
    end
  end
end
