module Spree
  module Products
    # Returns a product to draft, hiding it from the storefront while it is
    # worked on. Replaces the `draft` state machine event, which published no
    # event of its own — the `after_draft` hook is the extension point.
    class Draft < Spree::Workflow
      hooks :validate, :after_draft

      # @param product [Spree::Product]
      # @return [Spree::ServiceModule::Result] value is the product
      def perform(product:)
        super

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_draft
          run_hooks :after_draft
        end

        success(product)
      end

      private

      def mark_draft
        failure(product) unless product.update(status: 'draft')
      end
    end
  end
end
