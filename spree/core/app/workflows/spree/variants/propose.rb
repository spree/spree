module Spree
  module Variants
    # A seller submitting an offer for the marketplace to review.
    #
    # The offer's twin of Spree::Products::Propose: the only way onto
    # `proposed`, since a seller never assigns a status
    # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 3).
    #
    # Chains straight into Approve when the store does not review offers.
    class Propose < Spree::Workflow
      hooks :validate, :after_propose

      # @param variant [Spree::Variant]
      # @param submitted_by [Spree.admin_user_class, nil] who asked
      # @return [Spree::ServiceModule::Result] value is the variant
      def perform(variant:, submitted_by: nil)
        super

        # Only a row being worked on can be submitted. An offer already in
        # review, on sale or taken down has nothing to ask for.
        unless variant.draft? || variant.rejected?
          reject!(:cannot_propose, message: I18n.t('activerecord.errors.models.spree/variant.attributes.base.cannot_propose'))
        end

        # An offer with no price is not an offer: the buy box ranks on price
        # and would drop it, so the marketplace would be reviewing something
        # nobody could buy.
        reject!(:requires_price, message: I18n.t('activerecord.errors.models.spree/variant.attributes.base.requires_price')) if variant.prices.empty?

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_proposed
          step :open_submission
          run_hooks :after_propose
        end

        variant.publish_event('variant.proposed')

        return Spree.variant_approve_workflow.call(variant: variant, auto: true) if auto_approve?

        success(variant)
      end

      private

      def mark_proposed
        failure(variant) unless variant.update(status: 'proposed')
      end

      # A resubmission opens a fresh row rather than reopening the decided
      # one: the trail is how many times this was asked for.
      def open_submission
        variant.submissions.create!(status: 'pending', submitted_by: submitted_by)
      end

      def auto_approve?
        variant.product&.store&.preferred_auto_approve_seller_offers.present?
      end
    end
  end
end
