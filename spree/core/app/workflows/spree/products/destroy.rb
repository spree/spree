module Spree
  module Products
    # Soft-deletes a product. A workflow rather than a bare `destroy` so
    # cleanup that belongs to the host — unpublishing from a channel, telling
    # an ERP, archiving assets — has a place to attach, and so a store can
    # refuse the deletion outright (an active supplier contract, a product
    # still on a live campaign).
    class Destroy < Spree::Workflow
      hooks :validate, :after_destroy

      # `product` — the record about to be soft-deleted.

      # @param product [Spree::Product]
      # @return [Spree::ServiceModule::Result] value is the destroyed product
      def perform(product:)
        super

        run_hooks :validate

        ApplicationRecord.transaction do
          step :destroy_product
          run_hooks :after_destroy
        end

        success(product)
      end

      private

      def destroy_product
        failure(product) unless product.destroy
      end
    end
  end
end
