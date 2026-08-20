module Spree
  module Fulfillments
    # Manually creates a fulfillment (Spree::Shipment) on a completed order,
    # bypassing order routing. Moves the requested quantities of each line
    # item's not-yet-shipped inventory units out of their current shipments
    # into the new fulfillment, mirroring externally-managed fulfillment
    # (3PL, courier API, drop-shipping) back into Spree.
    #
    # Stock bookkeeping follows the split/transfer semantics: when the source
    # and target stock locations differ, moved quantities are restocked at the
    # source and unstocked at the target. Source shipments left empty are
    # destroyed and their cost and selected delivery method carry over to the
    # new fulfillment, unless the caller provides its own +cost+ /
    # +delivery_method+.
    #
    # The resulting cost is frozen only for fulfillments registered with
    # status: 'shipped' (rate refresh skips shipped shipments). Pending/ready
    # fulfillments participate in the standard rate machinery — this workflow
    # re-prices them from the delivery method calculators before the final
    # totals recalculation (repricing a completed order's delivery is an
    # explicit post-placement edit, never a side effect of a totals refresh).
    #
    # In the workflow tier for its hooks and its transaction discipline:
    # 3PL and courier integrations need to contribute provider payload and
    # to observe created fulfillments, and the guards now abort through
    # `failure`, which rolls the locked transaction back instead of
    # returning from inside it.
    class Create < Spree::Workflow
      hooks :validate, :get_provider_data, :after_create

      # The created fulfillment, and provider payload contributed by
      # get_provider_data handlers. Both nil while :validate runs.
      attr_reader :fulfillment, :provider_data

      # @param order [Spree::Order] completed order to fulfill
      # @param stock_location [Spree::StockLocation] location the fulfillment ships from
      # @param items [Array<Hash>, nil] `[{ line_item: Spree::LineItem, quantity: Integer }]`;
      #   nil fulfills every not-yet-shipped unit on the order
      # @param tracking [String, nil] carrier tracking number
      # @param delivery_method [Spree::ShippingMethod, nil] carrier; stored as the selected rate.
      #   Defaults to the delivery method of the drained source fulfillment(s)
      # @param cost [String, Numeric, nil] explicit shipping cost (e.g. the 3PL's price).
      #   Defaults to the summed cost of the drained source fulfillment(s), keeping the
      #   order total unchanged; an explicit cost changes the order total and payment state.
      #   Guaranteed to persist only with status: 'shipped' — pending fulfillments are
      #   re-priced by the rate engine (see class docs)
      # @param status [String, nil] pass 'shipped' to register an already-shipped fulfillment
      # @param metadata [Hash, nil] metadata stored on the fulfillment
      # @return [Spree::ServiceModule::Result] the created shipment on success
      def perform(order:, stock_location:, items: nil, tracking: nil, delivery_method: nil, cost: nil, status: nil, metadata: nil)
        super

        step :ensure_valid_status
        step :parse_requested_cost

        # Veto point — 3PL capacity, cut-off windows, per-location policy.
        # Before the lock: a rejection touches nothing.
        run_hooks :validate
        # Provider payload (carrier account, service level, customs data)
        # contributed by integrations, readable by after_create handlers.
        @provider_data = run_hooks :get_provider_data

        # The order row is locked before reading fulfillable units so
        # concurrent creations (e.g. duplicate carrier webhooks) validate and
        # move units against a serialized snapshot. The API layer already
        # serializes via with_order_lock; this covers direct callers.
        ApplicationRecord.transaction do
          order.lock!

          step :ensure_order_fulfillable
          step :build_fulfillment
          step :move_requested_units
          step :apply_status
          step :reprice_and_recalculate
        end

        run_hooks :after_create
        success(fulfillment.reload)
      end

      private

      def ensure_valid_status
        return if status.nil? || status == 'shipped'

        failure(nil, Spree.t('fulfillments.errors.invalid_status'))
      end

      # parse_cost returns a failure Result for an unparseable value; step
      # raises on a failure Result, so this aborts the flow.
      def parse_requested_cost
        @requested_cost = parse_cost(cost)
      end

      def ensure_order_fulfillable
        failure(nil, Spree.t('fulfillments.errors.order_not_completed')) unless order.completed?
        failure(nil, Spree.t('fulfillments.errors.order_canceled')) if order.canceled?
      end

      def build_fulfillment
        @units_by_line_item = fulfillable_units(order)
        @requested = normalize_items(order, items, @units_by_line_item)

        @fulfillment = order.fulfillments.new(
          stock_location: stock_location,
          address_id: order.ship_address_id,
          tracking: tracking
        )
        @fulfillment.metadata = metadata if metadata.present?
        @fulfillment.save!
      end

      def move_requested_units
        source_shipments = move_units(order, fulfillment, @requested, @units_by_line_item)
        inherited = destroy_drained_shipments(source_shipments, capture_delivery_method: delivery_method.nil?)
        attach_cost_and_rate(fulfillment, delivery_method, @requested_cost, inherited)
      end

      # A new fulfillment simply keeps its unfulfilled default unless the
      # caller registers it as already shipped.
      def apply_status
        mark_shipped(fulfillment) if status == 'shipped'
      end

      def reprice_and_recalculate
        reprice_pending_fulfillments(order.reload)
        order.recalculate_totals!
      end

      # Moved here from the old updater completed-order branch: pending/ready
      # fulfillments re-price from backoffice-visible delivery methods;
      # fulfilled ones keep their frozen cost.
      def reprice_pending_fulfillments(order)
        order.fulfillments.each do |fulfillment|
          next unless fulfillment.persisted?
          next if fulfillment.fulfilled?

          fulfillment.refresh_rates(Spree::DeliveryMethod::BACKOFFICE)
          fulfillment.update_amounts
        end
      end

      # Units that can still be moved into a manual fulfillment: on-hand or
      # backordered units sitting in shipments that haven't shipped or been
      # canceled (canceled shipments already restocked their stock). Loaded
      # in one query, on-hand first so moved units stay shippable, grouped
      # by line item for both validation and moving.
      def fulfillable_units(order)
        order.fulfillment_items.
          on_hand_or_backordered.
          joins(:fulfillment).
          merge(Spree::Fulfillment.ready_or_pending).
          preload(:fulfillment, :variant).
          order(Arel.sql("CASE WHEN #{Spree::FulfillmentItem.table_name}.status = 'on_hand' THEN 0 ELSE 1 END"), :id).
          group_by(&:line_item_id)
      end

      def normalize_items(order, items, units_by_line_item)
        available_for = ->(line_item) { units_by_line_item.fetch(line_item.id, []).sum(&:quantity) }

        if items.nil?
          derived = order.line_items.filter_map do |line_item|
            quantity = available_for.call(line_item)
            { line_item: line_item, quantity: quantity } if quantity.positive?
          end
          failure(nil, Spree.t('fulfillments.errors.no_items_to_fulfill')) if derived.empty?

          return derived
        end

        failure(nil, Spree.t('fulfillments.errors.no_items_to_fulfill')) if items.empty?

        # Merge duplicate line item entries, then validate quantities.
        merged = items.group_by { |item| item[:line_item].id }.values.map do |grouped|
          { line_item: grouped.first[:line_item], quantity: grouped.sum { |item| item[:quantity].to_i } }
        end

        merged.each do |item|
          line_item = item[:line_item]
          quantity = item[:quantity]

          unless quantity.positive?
            failure(nil, Spree.t('fulfillments.errors.invalid_quantity', item: line_item.prefixed_id))
          end

          available = available_for.call(line_item)
          if quantity > available
            failure(
              nil,
              Spree.t('fulfillments.errors.insufficient_quantity',
                      item: line_item.prefixed_id, requested: quantity, available: available)
            )
          end
        end

        merged
      end

      # Moves the requested quantities into the fulfillment, on-hand units
      # first so the new fulfillment is shippable whenever possible, and
      # carries each moved unit's allocation across with it so the promise
      # follows the fulfillment that will ship it.
      #
      # @return [Array<Spree::Shipment>] the shipments units were taken from
      def move_units(order, fulfillment, requested, units_by_line_item)
        source_shipments = []
        stock_moves = Hash.new(0)

        requested.each do |item|
          remaining = item[:quantity]

          units_by_line_item.fetch(item[:line_item].id, []).each do |unit|
            break if remaining.zero?

            take = [unit.quantity, remaining].min
            source_shipments << unit.fulfillment
            stock_moves[[unit.fulfillment, unit.variant]] += take

            target = fulfillment.fulfillment_items.find_or_initialize_by(
              status: unit.status,
              variant_id: unit.variant_id,
              line_item_id: unit.line_item_id,
              order_id: order.id
            )
            target.pending = unit.pending
            # The quantity column has a database default of 1, so a fresh
            # record must be set to the moved quantity, not incremented.
            target.quantity = target.new_record? ? take : target.quantity + take
            target.save!

            if take == unit.quantity
              unit.destroy!
            else
              unit.update!(quantity: unit.quantity - take)
            end

            remaining -= take
          end
        end

        # Re-pointing a promise moves no goods, so this runs even when the
        # origin does not change: allocation is keyed to the fulfillment, and
        # the quantity Spree::Fulfillments::Fulfill reads to decide what
        # shipped would otherwise sit on the wrong one. Only a promise that
        # exists can move — a fulfillment on an order that was never placed,
        # or one created before typed movements, carries nothing.
        stock_moves.each do |(source_shipment, variant), quantity|
          next unless variant.track_inventory?

          carried = [source_shipment.allocated_quantities[variant.id].to_i, quantity].min
          next unless carried.positive?

          source_shipment.stock_location.release(variant, carried, source_shipment)
          fulfillment.stock_location.allocate(variant, carried, fulfillment)
        end

        source_shipments.uniq
      end

      # Destroys fully drained source shipments, capturing what the new
      # fulfillment inherits from them — the summed cost and the first
      # selected delivery method, read before destroy since the rates are
      # deleted along with the shipment. The delivery method lookup costs
      # queries, so it is skipped when the caller provided its own.
      #
      # @return [Hash] `{ cost: BigDecimal, delivery_method: Spree::ShippingMethod or nil }`
      def destroy_drained_shipments(source_shipments, capture_delivery_method:)
        inherited = { cost: 0, delivery_method: nil }

        source_shipments.each do |shipment|
          next unless shipment.fulfillment_items.sum(:quantity).zero?

          inherited[:cost] += shipment.cost
          inherited[:delivery_method] ||= shipment.delivery_method if capture_delivery_method
          shipment.destroy!
        end

        inherited
      end

      # The fulfillment inherits the cost and carrier of the shipments it
      # replaced — keeping the order total (and thus payment state) unchanged —
      # unless the caller provides its own. Frozen once shipped; see the class
      # docs for pending-path re-pricing. The carrier rides along as a
      # selected rate.
      def attach_cost_and_rate(fulfillment, delivery_method, cost, inherited)
        effective_cost = cost || inherited[:cost]
        method = delivery_method || inherited[:delivery_method]

        fulfillment.update_columns(cost: effective_cost) if effective_cost.positive?
        fulfillment.add_delivery_method(method, true) if method
      end

      # Strict decimal parsing (same semantics as Shipment#cost=, which the
      # update_columns freeze path bypasses) — the lenient LocalizedNumber
      # would turn garbage into 0, and 0 is a legal cost here.
      #
      # @return [BigDecimal, Numeric, nil] nil when no cost was given (blank
      #   counts as omitted); a failure Result for malformed or negative input
      def parse_cost(cost)
        return if cost.blank?

        parsed = cost.is_a?(String) ? BigDecimal(cost.strip) : cost
        failure(nil, Spree.t('fulfillments.errors.invalid_cost')) if parsed.negative?

        parsed
      rescue ArgumentError
        failure(nil, Spree.t('fulfillments.errors.invalid_cost'))
      end

      # Registers an externally-completed fulfillment: backorders are filled
      # (the external location evidently had the goods) and the readiness gate
      # is forced — the goods already left, so refusing on an unpaid order
      # would just refuse to record history.
      def mark_shipped(fulfillment)
        fulfillment.fulfillment_items.backordered.update_all(status: 'on_hand', updated_at: Time.current)
        fulfillment.reload
        Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment, force: true)
      end
    end
  end
end
