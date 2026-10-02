module Spree
  module Returns
    # Withdraws a return that has not been received yet.
    #
    # Nothing is restocked and no money moves — cancelling is only valid
    # before the goods arrive. Once a return is received the merchant is
    # holding the customer's items, and the way out is a refund, not a
    # cancellation.
    class Cancel < Spree::Workflow
      include Spree::PostSale::Cancellation

      hooks :validate, :after_cancel

      # @param return_record [Spree::Return]
      # @param reason [String, nil] staff- or customer-supplied note
      def perform(return_record:, reason: nil)
        super

        # Carrier I/O, after the status is committed: a customer who abandons
        # a return must not be left holding live prepaid postage the merchant
        # is still paying for.
        cancel { external_step :refund_prepaid_label }
      end

      private

      def post_sale_record = return_record
      def cancellable_statuses = %w[requested approved]

      def refund_prepaid_label
        Spree::Fulfillments::StandDownProvider.refund_labels(return_record)
      end
    end
  end
end
