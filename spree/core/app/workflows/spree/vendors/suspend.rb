module Spree
  module Vendors
    # Halts a trading vendor: their catalog stops selling, their record and
    # history stay. Reversible through Spree::Vendors::Approve.
    class Suspend < Spree::Workflow
      hooks :validate, :after_suspend

      # @param vendor [Spree::Vendor]
      # @param reason [String, nil] why, for the vendor and the audit trail
      # @param suspended_by [Object, nil] the staff member suspending
      def perform(vendor:, reason: nil, suspended_by: nil)
        super

        step :ensure_suspendable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_suspended
        end

        run_hooks :after_suspend
        vendor.publish_event('vendor.suspended')
        success(vendor.reload)
      end

      private

      # Anyone already admitted can be stopped — including a vendor still
      # setting themselves up, since a marketplace may need to halt someone
      # mid-onboarding. What cannot be suspended is a vendor who has not been
      # admitted at all; turning those away is Reject, which says something
      # different and is not the same undo.
      def ensure_suspendable
        failure(vendor, :already_suspended) if vendor.suspended?

        return if vendor.approved? || vendor.onboarding? || vendor.ready_for_review?

        failure(vendor, :not_suspendable)
      end

      def mark_suspended
        vendor.update!(status: 'suspended')
        record_reason
      end

      # Kept in metadata rather than a column: it is a note about one event,
      # and the next suspension will have its own.
      def record_reason
        return if reason.blank?

        vendor.update!(metadata: vendor.metadata.to_h.merge('suspension_reason' => reason))
      end
    end
  end
end
