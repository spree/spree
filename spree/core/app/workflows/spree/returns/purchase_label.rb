module Spree
  module Returns
    # Buys the customer's return label: an inbound parcel from the address
    # the order shipped to back to the return's stock location, bought
    # through the provider that shipped the goods out. The label attaches to
    # the return as its owner and mints the inbound delivery, whose arrival
    # never receives the return — Spree::Returns::Receive stays a staff act.
    class PurchaseLabel < Spree::Workflow
      hooks :validate, :after_purchase_label

      # @param return_record [Spree::Return]
      # @return [Spree::ServiceModule::Result] the return with its label on success
      def perform(return_record:)
        super

        run_hooks :validate

        step :purchase

        run_hooks :after_purchase_label
        success(return_record.reload)
      end

      private

      def purchase
        result = Spree.shipping_label_purchase_workflow.call(owner: return_record)
        failure(return_record, result.error.to_s) if result.failure?
      end
    end
  end
end
