module Spree
  module Sellers
    # Sends a seller back to onboarding: the operator looked at them and
    # something has to be redone.
    #
    # Distinct from Reject, which turns a seller away. This one expects them
    # back, which is why it carries a note — a seller told only "not yet" has
    # nothing to act on.
    class ReopenOnboarding < Spree::Workflow
      hooks :validate, :after_reopen

      # @param seller [Spree::Seller]
      # @param note [String, nil] what the seller has to fix
      # @param reopened_by [Object, nil] the staff member sending it back
      def perform(seller:, note: nil, reopened_by: nil)
        super

        step :ensure_reopenable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_onboarding
        end

        run_hooks :after_reopen
        seller.publish_event('seller.onboarding_reopened')
        success(seller.reload)
      end

      private

      # Only a seller waiting on the operator can be sent back. One already
      # approved is suspended instead, which says the right thing to the
      # shopper as well as to the seller.
      def ensure_reopenable
        return if seller.ready_for_review?

        failure(seller, :not_reopenable)
      end

      def mark_onboarding
        seller.update!(status: 'onboarding')
        record_note
      end

      # A note about one decision, replaced by the next one — metadata rather
      # than a column, like the suspension reason beside it.
      def record_note
        return if note.blank?

        seller.update!(metadata: seller.metadata.to_h.merge('onboarding_reopened_note' => note))
      end
    end
  end
end
