module Spree
  module Returns
    # Withdraws a return that has not been received yet.
    #
    # Nothing is restocked and no money moves — cancelling is only valid
    # before the goods arrive. Once a return is received the merchant is
    # holding the customer's items, and the way out is a refund, not a
    # cancellation.
    class Cancel < Spree::Workflow
      hooks :validate, :after_cancel

      # @param return_record [Spree::Return]
      # @param reason [String, nil] staff- or customer-supplied note
      def perform(return_record:, reason: nil)
        super

        step :ensure_cancellable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_canceled
        end

        # Carrier I/O, after the status is committed: a customer who abandons
        # a return must not be left holding live prepaid postage the merchant
        # is still paying for.
        external_step :refund_prepaid_label

        run_hooks :after_cancel
        return_record.publish_event('return.canceled')
        success(return_record.reload)
      end

      private

      def ensure_cancellable
        return if return_record.requested? || return_record.approved?

        failure(return_record, :not_cancellable)
      end

      def refund_prepaid_label
        Spree::Fulfillments::StandDownProvider.refund_labels(return_record)
      end

      def mark_canceled
        memo = [return_record.memo, reason].compact_blank.join("\n")
        return_record.update!(status: 'canceled', canceled_at: Time.current, memo: memo.presence)
      end
    end
  end
end
