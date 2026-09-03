module Spree
  module Fulfillments
    # Buys the shipping label for a parcel that has not shipped yet — the step
    # a warehouse performs BEFORE anything is handed over: print the label,
    # stick it on the box, then mark the fulfillment fulfilled.
    #
    # This is where a purchase failure is loud. The one-click fulfill path
    # degrades a label failure to "no label yet" because a carrier outage must
    # never stop a merchant recording a parcel that physically left; here
    # nothing has left, so a failed purchase simply fails and the merchant
    # retries.
    #
    # Thin over Spree::ShippingLabels::Purchase, kept as its own workflow for
    # the hooks that have been public since the label-leads amendment.
    class PurchaseLabel < Spree::Workflow
      hooks :validate, :after_purchase_label

      # @param fulfillment [Spree::Fulfillment] the parcel to buy a label for
      # @return [Spree::ServiceModule::Result] the fulfillment with its label
      #   and delivery attached on success
      def perform(fulfillment:)
        super

        run_hooks :validate

        step :purchase

        run_hooks :after_purchase_label
        success(fulfillment.reload)
      end

      private

      def purchase
        result = Spree.shipping_label_purchase_workflow.call(owner: fulfillment)
        failure(fulfillment, result.error.to_s) if result.failure?
      end
    end
  end
end
