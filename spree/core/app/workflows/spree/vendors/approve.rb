module Spree
  module Vendors
    # Lets a vendor trade. Also the way back for one that was suspended or
    # turned down, which is why the guard admits more than the linear path.
    class Approve < Spree::Workflow
      hooks :validate, :after_approve

      # @param vendor [Spree::Vendor]
      # @param approver [Object, nil] the staff member approving
      def perform(vendor:, approver: nil)
        super

        step :ensure_approvable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_approved
        end

        run_hooks :after_approve
        vendor.publish_event('vendor.approved')
        success(vendor.reload)
      end

      private

      def ensure_approvable
        failure(vendor, :already_approved) if vendor.approved?

        return if vendor.onboarding? || vendor.ready_for_review? ||
                  vendor.suspended? || vendor.rejected?

        failure(vendor, :not_approvable)
      end

      # Lifting a suspension clears the holiday with it: a vendor coming back
      # is coming back to sell, and leaving them invisible would look like the
      # approval had not worked.
      def mark_approved
        vendor.update!(status: 'approved', holiday_mode_until: nil)
      end
    end
  end
end
