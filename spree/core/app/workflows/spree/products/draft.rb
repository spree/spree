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
          step :withdraw_submission
          run_hooks :after_draft
        end

        success(product)
      end

      private

      def mark_draft
        failure(product) unless product.update(status: 'draft')
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
