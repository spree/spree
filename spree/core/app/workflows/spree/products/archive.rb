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
          step :withdraw_submission
          run_hooks :after_archive
        end

        product.publish_event('product.archived')
        success(product)
      end

      private

      def mark_archived
        failure(product) unless product.update(status: 'archived')
      end

      # Taking a listing back before the marketplace ruled on it settles the
      # open row, so `pending` never means "abandoned". A product that was
      # not in review has nothing to withdraw.
      def withdraw_submission
        return unless product.status_previously_was.in?(Spree::Product::REVIEW_STATUSES)

        Spree::ProductSubmissions::Close.call(product: product, status: 'withdrawn')
      end
    end
  end
end
