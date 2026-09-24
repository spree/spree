module Spree
  module Fulfillments
    # Updates a fulfillment and keeps the owning order's money and statuses
    # in step with it.
    #
    # Three changes ripple beyond the row itself. Selecting a different delivery
    # rate re-prices the fulfillment, which can move the order total and with
    # it the payment status. Moving the fulfillment to another origin
    # invalidates its rates outright — they were quoted for the old location,
    # which may not even offer the same methods — so the flow re-quotes,
    # keeping the merchant's chosen method where the new origin still offers
    # it and falling back to the estimator's pick where it does not.
    #
    # A delivery cost staff set by hand is the third: it is recorded as
    # +cost_source: 'manual'+, and from then on neither a rate change nor a
    # re-quote restates it — only an explicit revert does.
    #
    # In the workflow tier for its hooks and transaction discipline: moving a
    # fulfillment between warehouses is exactly the decision a 3PL or
    # per-location policy wants to veto, and the repricing that follows has to
    # roll back with it.
    class Update < Spree::Workflow
      include Spree::Fulfillments::CostParsing

      hooks :validate, :after_update

      # Distinguishes "cost not passed" from the explicit +cost: nil+ revert.
      COST_NOT_PROVIDED = Object.new.freeze

      # @param fulfillment [Spree::Fulfillment] the fulfillment to update
      # @param fulfillment_attributes [Hash] attributes to assign; +stock_location_id+
      #   moves the fulfillment, +selected_delivery_rate_id+ changes its rate,
      #   +tracking+ (with +tracking_carrier+) creates or corrects the primary
      #   delivery — a corrected number starts its carrier journey over
      # @param cost [String, Numeric, nil] a delivery cost set by hand, which
      #   no re-quote restates; +nil+ hands the parcel back to its delivery
      #   rate. Omit to leave the cost alone
      # @param shipment [Spree::Fulfillment, nil] @deprecated use +fulfillment+
      # @param shipment_attributes [Hash, nil] @deprecated use +fulfillment_attributes+
      # @return [Spree::ServiceModule::Result] the updated fulfillment on success
      def perform(fulfillment: nil, fulfillment_attributes: nil, cost: COST_NOT_PROVIDED, shipment: nil, shipment_attributes: nil)
        super

        if shipment || shipment_attributes
          Spree::Deprecation.warn(
            'Calling Spree::Fulfillments::Update with shipment:/shipment_attributes: keywords is deprecated ' \
            'and will be removed in Spree 6.1. Use fulfillment:/fulfillment_attributes: instead.'
          )
        end

        @fulfillment = fulfillment || shipment
        @attributes = (fulfillment_attributes || shipment_attributes || {}).to_h.with_indifferent_access
        @tracking = @attributes.delete(:tracking)
        @tracking_carrier = @attributes.delete(:tracking_carrier)
        @origin_changed = origin_change?

        step :parse_requested_cost

        # Veto point — per-location policy, 3PL capacity, cut-off windows.
        # Before the transaction: a rejection touches nothing.
        run_hooks :validate

        ApplicationRecord.transaction do
          step :assign_attributes
          step :apply_tracking
          step :requote_after_origin_change
          step :reprice_after_rate_change
          step :apply_cost
        end

        run_hooks :after_update
        success(@fulfillment)
      end

      # The fulfillment being updated, readable by hook handlers.
      attr_reader :fulfillment

      # The parsed cost this update sets, or nil when it sets none.
      attr_reader :requested_cost

      # Whether this update moves the fulfillment to another origin.
      def origin_changed?
        @origin_changed
      end

      # Whether this update sets or reverts the delivery cost.
      def cost_provided?
        !cost.equal?(COST_NOT_PROVIDED)
      end

      private

      # Blank is refused rather than read as a revert: only an explicit nil
      # hands the parcel back to its rate.
      def parse_requested_cost
        return if !cost_provided? || cost.nil?

        @requested_cost = parse_cost(cost)
      end

      def assign_attributes
        failure(@fulfillment) unless @fulfillment.update(@attributes)
      end

      def apply_tracking
        result = Spree.delivery_upsert_primary_service.call(
          fulfillment: @fulfillment, tracking: @tracking, carrier: @tracking_carrier
        )
        failure(@fulfillment, result.error.to_s) if result.failure?
      end

      def requote_after_origin_change
        return unless @origin_changed

        @fulfillment.refresh_rates(Spree::DeliveryMethod::BACKOFFICE)
        @fulfillment.update_amounts
        # A cost in the same update recalculates once, after it is written.
        @fulfillment.owner&.recalculate_totals! unless cost_provided?
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
        return if cost_provided?

        order.recalculate_totals!

        # A new rate changes what the delivery costs, never where the package
        # is in its lifecycle — the old machine recomputed the status here from
        # the order's payment state, which is precisely the coupling removed in
        # 6.0. The rollup still runs because the order's totals moved.
        order.update_statuses!
      end

      # Runs after the rate change, so a revert sent with a new rate restates
      # the new rate's cost. The explicit recalculation is required: the
      # model's own skips placed orders.
      def apply_cost
        return unless cost_provided?

        if cost.nil?
          revert_cost
        else
          @fulfillment.update_columns(
            cost: requested_cost, cost_source: Spree::Fulfillment::MANUAL_COST_SOURCE, updated_at: Time.current
          )
        end

        @fulfillment.owner&.recalculate_totals!
        @fulfillment.order&.update_statuses!
      end

      # Back to what the selected rate charges, which is what the cost was
      # before the override. A parcel with no rate is quoted first; one that
      # nothing can quote keeps its amount, and only the marker clears.
      def revert_cost
        if @fulfillment.selected_delivery_rate.nil?
          @fulfillment.refresh_rates(Spree::DeliveryMethod::BACKOFFICE)
          @fulfillment.reload
        end

        attributes = { cost_source: nil, updated_at: Time.current }
        attributes[:cost] = @fulfillment.selected_delivery_rate.cost if @fulfillment.selected_delivery_rate
        @fulfillment.update_columns(attributes)
      end

      def rate_change?
        @attributes.key?(:selected_shipping_rate_id) || @attributes.key?(:selected_delivery_rate_id)
      end

      # True only when the caller is actually moving the fulfillment, not
      # resubmitting the location it already has.
      def origin_change?
        requested = @attributes[:stock_location_id]
        return false if requested.blank?

        requested.to_s != @fulfillment.stock_location_id.to_s
      end
    end
  end
end
