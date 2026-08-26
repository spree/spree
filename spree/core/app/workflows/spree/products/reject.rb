module Spree
  module Products
    # The operator turning a submitted product down.
    #
    # The reason rides in metadata rather than a column: it is a note back to
    # the seller, not a queryable concept, and a table for one string would
    # outlive its usefulness.
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
          reject!(I18n.t('activerecord.errors.models.spree/product.attributes.base.not_awaiting_review'))
        end

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_rejected
          run_hooks :after_reject
        end

        product.publish_event('product.rejected')
        success(product)
      end

      private

      def mark_rejected
        attributes = { status: 'rejected' }
        attributes[:metadata] = product.metadata.to_h.merge('rejection_reason' => reason) if reason.present?

        failure(product) unless product.update(attributes)
      end
    end
  end
end
