module Spree
  module Variants
    # Returns an offer to draft — the seller taking their listing down while
    # they work on it (docs/plans/6.0-seller-master-catalog-listings.md).
    class Draft < Spree::Workflow
      hooks :validate, :after_draft

      # @param variant [Spree::Variant]
      # @return [Spree::ServiceModule::Result] value is the variant
      def perform(variant:)
        super

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_draft
          step :withdraw_submission
          run_hooks :after_draft
        end

        variant.publish_event('variant.drafted')
        success(variant)
      end

      private

      def mark_draft
        failure(variant) unless variant.update(status: 'draft')
      end

      # Taking an offer back before the marketplace ruled on it settles the
      # open row, so `pending` never means "abandoned". Only an open row: a
      # rejected offer has already been decided.
      def withdraw_submission
        return unless variant.latest_submission&.pending?

        Spree::ProductSubmissions::Close.call(product: variant.product, variant: variant, status: 'withdrawn')
      end
    end
  end
end
