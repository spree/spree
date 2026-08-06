module Spree
  module Returns
    # Authorizes a requested return.
    #
    # No return-label generation here: a prepaid label is carrier output, and
    # every comparable platform treats it as fulfillment-provider data rather
    # than state on the return (Medusa returns `label_url` on a fulfillment,
    # Saleor's Fulfillment carries only a tracking number, Vendure has no
    # return-label concept at all). It arrives with the carrier provider in
    # 6.0-delivery-rate-provider.md; a store needing one before then can put
    # the URL in the return's `metadata`.
    class Approve < Spree::Workflow
      hooks :validate, :after_approve

      # @param return_record [Spree::Return]
      # @param approver [Object, nil] the admin approving it
      def perform(return_record:, approver: nil)
        super

        step :ensure_approvable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_approved
        end

        run_hooks :after_approve
        return_record.publish_event('return.approved')
        success(return_record.reload)
      end

      private

      def ensure_approvable
        failure(return_record, :not_requested) unless return_record.requested?
      end

      def mark_approved
        return_record.update!(
          status: 'approved',
          approved_at: Time.current,
          created_by: return_record.created_by || approver
        )
      end
    end
  end
end
