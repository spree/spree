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
      # open row, so `pending` never means "abandoned".
      #
      # Only an open row: a rejected product has already been decided, and
      # inventing a `withdrawn` row for it would bury that decision under an
      # entry nobody made.
      def withdraw_submission
        return unless product.submissions.latest_first.first&.pending?

        Spree::ProductSubmissions::Close.call(product: product, status: 'withdrawn')
      end
    end
  end
end
