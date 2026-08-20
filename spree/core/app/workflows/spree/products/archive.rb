module Spree
  module Products
    # Takes a product off sale for good. Replaces the `archive` state machine
    # event.
    class Archive < Spree::Workflow
      hooks :validate, :after_archive

      # @param product [Spree::Product]
      # @return [Spree::ServiceModule::Result] value is the product
      def perform(product:)
        super

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_archived
          run_hooks :after_archive
        end

        product.publish_event('product.archived')
        success(product)
      end

      private

      def mark_archived
        failure(product) unless product.update(status: 'archived')
      end
    end
  end
end
