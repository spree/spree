module Spree
  module Products
    # Takes a product off sale for good. Replaces the `archive` state machine
    # event.
    class Archive < Spree::Workflow
      include StatusTransition

      hooks :validate, :after_archive

      # @param product [Spree::Product]
      # @return [Spree::ServiceModule::Result] value is the product
      def perform(product:)
        super

        run_hooks :validate

        moved = ApplicationRecord.transaction do
          next false if already_in?('archived')

          step :mark_archived
          step :withdraw_submission
          run_hooks :after_archive
          true
        end

        product.publish_event('product.archived') if moved
        success(product)
      end

      private

      def mark_archived
        failure(product) unless product.update(status: 'archived')
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
