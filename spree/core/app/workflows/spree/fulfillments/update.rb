module Spree
  module Fulfillments
    # Updates a fulfillment and keeps the owning order's money and statuses
    # in step with it.
    #
    # Two changes ripple beyond the row itself. Selecting a different delivery
    # rate re-prices the fulfillment, which can move the order total and with
    # it the payment status. Moving the fulfillment to another origin
    # invalidates its rates outright — they were quoted for the old location,
    # which may not even offer the same methods — so the flow re-quotes,
    # keeping the merchant's chosen method where the new origin still offers
    # it and falling back to the estimator's pick where it does not.
    #
    # In the workflow tier for its hooks and transaction discipline: moving a
    # fulfillment between warehouses is exactly the decision a 3PL or
    # per-location policy wants to veto, and the repricing that follows has to
    # roll back with it.
    class Update < Spree::Workflow
      hooks :validate, :after_update

      # @param fulfillment [Spree::Fulfillment] the fulfillment to update
      # @param fulfillment_attributes [Hash] attributes to assign; +stock_location_id+
      #   moves the fulfillment, +selected_delivery_rate_id+ changes its rate
      # @param shipment [Spree::Fulfillment, nil] @deprecated use +fulfillment+
      # @param shipment_attributes [Hash, nil] @deprecated use +fulfillment_attributes+
      # @return [Spree::ServiceModule::Result] the updated fulfillment on success
      def perform(fulfillment: nil, fulfillment_attributes: nil, shipment: nil, shipment_attributes: nil)
        super

        if shipment || shipment_attributes
          Spree::Deprecation.warn(
            'Calling Spree::Fulfillments::Update with shipment:/shipment_attributes: keywords is deprecated ' \
            'and will be removed in Spree 6.1. Use fulfillment:/fulfillment_attributes: instead.'
          )
        end

        @fulfillment = fulfillment || shipment
        @attributes = (fulfillment_attributes || shipment_attributes || {}).to_h
        @origin_changed = origin_change?

        # Veto point — per-location policy, 3PL capacity, cut-off windows.
        # Before the transaction: a rejection touches nothing.
        run_hooks :validate

        ApplicationRecord.transaction do
          step :assign_attributes
          step :requote_after_origin_change
          step :reprice_after_rate_change
        end

        run_hooks :after_update
        success(@fulfillment)
      end

      # The fulfillment being updated, readable by hook handlers.
      attr_reader :fulfillment

      # Whether this update moves the fulfillment to another origin.
      def origin_changed?
        @origin_changed
      end

      private

      def assign_attributes
        failure(@fulfillment) unless @fulfillment.update(@attributes)
      end

      def requote_after_origin_change
        return unless @origin_changed

        @fulfillment.refresh_rates(Spree::DeliveryMethod::BACKOFFICE)
        @fulfillment.update_amounts
        @fulfillment.owner&.recalculate_totals!
      end

      # Changing the selected rate does not update the cost on its own, so the
      # fulfillment cost is persisted before the order total is recalculated —
      # the new total is what decides the payment status, which in turn decides
      # the fulfillment status.
      def reprice_after_rate_change
        return unless rate_change?

        order = @fulfillment.order
        return if order.nil?

        @fulfillment.update_amounts
        order.recalculate_totals!

        @fulfillment.update_columns(
          status: @fulfillment.determine_state(order),
          updated_at: Time.current
        )

        order.update_statuses!
      end

      def rate_change?
        @attributes.key?(:selected_shipping_rate_id) || @attributes.key?('selected_shipping_rate_id') ||
          @attributes.key?(:selected_delivery_rate_id) || @attributes.key?('selected_delivery_rate_id')
      end

      # True only when the caller is actually moving the fulfillment, not
      # resubmitting the location it already has.
      def origin_change?
        requested = @attributes[:stock_location_id] || @attributes['stock_location_id']
        return false if requested.blank?

        requested.to_s != @fulfillment.stock_location_id.to_s
      end
    end
  end
end
