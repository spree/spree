module Spree
  module Sellers
    # Lets a seller trade. Also the way back for one that was suspended or
    # turned down, which is why the guard admits more than the linear path.
    class Approve < Spree::Workflow
      hooks :validate, :after_approve

      # @param seller [Spree::Seller]
      # @param approver [Object, nil] the staff member approving
      def perform(seller:, approver: nil)
        super

        step :ensure_approvable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_approved
        end

        run_hooks :after_approve
        seller.publish_event('seller.approved')
        success(seller.reload)
      end

      private

      def ensure_approvable
        failure(seller, :already_approved) if seller.approved?

        return if seller.onboarding? || seller.ready_for_review? ||
                  seller.suspended? || seller.rejected?

        failure(seller, :not_approvable)
      end

      # Lifting a suspension clears the holiday with it: a seller coming back
      # is coming back to sell, and leaving them invisible would look like the
      # approval had not worked.
      def mark_approved
        seller.update!(status: 'approved', holiday_mode_until: nil)
      end
    end
  end
end
