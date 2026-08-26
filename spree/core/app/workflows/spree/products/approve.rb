module Spree
  module Products
    # The operator accepting a submitted product, putting it on sale.
    #
    # Separate from Activate, which is the operator publishing their own
    # catalog and answers to nobody: this one closes a review a seller opened,
    # so it refuses anything that is not awaiting one.
    class Approve < Spree::Workflow
      hooks :validate, :after_approve

      # @param product [Spree::Product]
      # @param reviewer [Spree.admin_user_class, nil] who decided
      # @return [Spree::ServiceModule::Result] value is the product
      def perform(product:, reviewer: nil)
        super

        reject!(I18n.t('activerecord.errors.models.spree/product.attributes.base.not_awaiting_review')) unless product.proposed?

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_active
          run_hooks :after_approve
        end

        product.publish_event('product.approved')
        success(product)
      end

      private

      def mark_active
        failure(product) unless product.update(status: 'active')
      end
    end
  end
end
