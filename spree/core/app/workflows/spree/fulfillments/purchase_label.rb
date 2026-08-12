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
    class PurchaseLabel < Spree::Workflow
      hooks :validate, :after_purchase_label

      # @param fulfillment [Spree::Fulfillment] the parcel to buy a label for
      # @return [Spree::ServiceModule::Result] the fulfillment with tracking
      #   and label attached on success
      def perform(fulfillment:)
        super

        run_hooks :validate

        step :ensure_purchasable

        # Carrier I/O — never inside a transaction.
        external_step :purchase

        run_hooks :after_purchase_label
        success(fulfillment.reload)
      end

      private

      def ensure_purchasable
        unless fulfillment.provider.class.generates_labels?
          failure(fulfillment, Spree.t('fulfillments.errors.provider_has_no_labels'))
        end

        unless fulfillment.unfulfilled?
          failure(fulfillment, Spree.t('fulfillments.errors.cannot_purchase_label'))
        end

        failure(fulfillment, Spree.t('fulfillments.errors.order_draft')) if fulfillment.order&.draft?
      end

      # The provider is idempotent about an already-bought label (it returns
      # the stored purchase), so re-running after a partial failure is safe.
      def purchase
        result = fulfillment.provider.create_fulfillment(fulfillment)

        unless result.is_a?(Hash) && result[:tracking_number].present?
          failure(fulfillment, Spree.t('fulfillments.errors.label_purchase_failed'))
        end

        return if fulfillment.tracking.present?

        # update! so carrier detection pins the badge and tracking URL.
        fulfillment.update!(tracking: result[:tracking_number])
      end
    end
  end
end
