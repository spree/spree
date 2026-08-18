module Spree
  module Sellers
    # Halts a trading seller: their catalog stops selling, their record and
    # history stay. Reversible through Spree::Sellers::Approve.
    class Suspend < Spree::Workflow
      hooks :validate, :after_suspend

      # @param seller [Spree::Seller]
      # @param reason [String, nil] why, for the seller and the audit trail
      # @param suspended_by [Object, nil] the staff member suspending
      def perform(seller:, reason: nil, suspended_by: nil)
        super

        step :ensure_suspendable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_suspended
        end

        run_hooks :after_suspend
        seller.publish_event('seller.suspended')
        success(seller.reload)
      end

      private

      # Anyone already admitted can be stopped — including a seller still
      # setting themselves up, since a marketplace may need to halt someone
      # mid-onboarding. What cannot be suspended is a seller who has not been
      # admitted at all; turning those away is Reject, which says something
      # different and is not the same undo.
      def ensure_suspendable
        failure(seller, :already_suspended) if seller.suspended?

        return if seller.approved? || seller.onboarding? || seller.ready_for_review?

        failure(seller, :not_suspendable)
      end

      def mark_suspended
        seller.update!(status: 'suspended')
        record_reason
      end

      # Kept in metadata rather than a column: it is a note about one event,
      # and the next suspension will have its own.
      def record_reason
        return if reason.blank?

        seller.update!(metadata: seller.metadata.to_h.merge('suspension_reason' => reason))
      end
    end
  end
end
