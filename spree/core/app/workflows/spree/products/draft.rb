module Spree
  module Products
    # Returns a product to draft, hiding it from the storefront while it is
    # worked on. Replaces the `draft` state machine event.
    class Draft < Spree::Workflow
      include StatusTransition

      hooks :validate, :after_draft

      # @param product [Spree::Product]
      # @return [Spree::ServiceModule::Result] value is the product
      def perform(product:)
        super

        run_hooks :validate

        moved = ApplicationRecord.transaction do
          next false if already_in?('draft')

          step :mark_draft
          step :withdraw_submission
          run_hooks :after_draft
          true
        end

        # Its siblings (Activate, Archive, Propose, Approve, Reject) all
        # announce themselves, and this one now carries a marketplace meaning
        # too: taking a listing back withdraws an open submission, which a
        # seller's integration has the same reason to hear about.
        product.publish_event('product.drafted') if moved

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
