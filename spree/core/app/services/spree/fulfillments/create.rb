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
    # fulfillments participate in the standard rate machinery — the order
    # updater re-prices them from the delivery method calculators on the next
    # recalculation, exactly like shipments created via split/transfer.
    class Create
      prepend Spree::ServiceModule::Base

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
      def call(order:, stock_location:, items: nil, tracking: nil, delivery_method: nil, cost: nil, status: nil, metadata: nil)
        return failure(nil, Spree.t('fulfillments.errors.invalid_status')) unless status.nil? || status == 'shipped'

        cost = parse_cost(cost)
        return cost if cost.is_a?(Spree::ServiceModule::Result)

        fulfillment = nil

        # The order row is locked before reading fulfillable units so
        # concurrent creations (e.g. duplicate carrier webhooks) validate and
        # move units against a serialized snapshot. The API layer already
        # serializes via with_order_lock; this covers direct service callers.
        ActiveRecord::Base.transaction do
          order.lock!

          return failure(nil, Spree.t('fulfillments.errors.order_not_completed')) unless order.completed?
          return failure(nil, Spree.t('fulfillments.errors.order_canceled')) if order.canceled?

          units_by_line_item = fulfillable_units(order)

          requested = normalize_items(order, items, units_by_line_item)
          return requested if requested.is_a?(Spree::ServiceModule::Result)

          fulfillment = order.shipments.new(
            stock_location: stock_location,
            address_id: order.ship_address_id,
            tracking: tracking
          )
          fulfillment.metadata = metadata if metadata.present?
          fulfillment.save!

          source_shipments = move_units(order, fulfillment, requested, units_by_line_item)
          inherited = destroy_drained_shipments(source_shipments, capture_delivery_method: delivery_method.nil?)
          attach_cost_and_rate(fulfillment, delivery_method, cost, inherited)

          if status == 'shipped'
            mark_shipped(fulfillment)
          else
            fulfillment.update!(order)
          end

          order.reload.update_with_updater!
        end

        success(fulfillment.reload)
      end

      private

      # Units that can still be moved into a manual fulfillment: on-hand or
      # backordered units sitting in shipments that haven't shipped or been
      # canceled (canceled shipments already restocked their stock). Loaded
      # in one query, on-hand first so moved units stay shippable, grouped
      # by line item for both validation and moving.
      def fulfillable_units(order)
        order.inventory_units.
          on_hand_or_backordered.
          joins(:shipment).
          merge(Spree::Shipment.ready_or_pending).
          preload(:shipment, :variant).
          order(Arel.sql("CASE WHEN #{Spree::InventoryUnit.table_name}.state = 'on_hand' THEN 0 ELSE 1 END"), :id).
          group_by(&:line_item_id)
      end

      def normalize_items(order, items, units_by_line_item)
        available_for = ->(line_item) { units_by_line_item.fetch(line_item.id, []).sum(&:quantity) }

        if items.nil?
          derived = order.line_items.filter_map do |line_item|
            quantity = available_for.call(line_item)
            { line_item: line_item, quantity: quantity } if quantity.positive?
          end
          return failure(nil, Spree.t('fulfillments.errors.no_items_to_fulfill')) if derived.empty?

          return derived
        end

        return failure(nil, Spree.t('fulfillments.errors.no_items_to_fulfill')) if items.empty?

        # Merge duplicate line item entries, then validate quantities.
        merged = items.group_by { |item| item[:line_item].id }.values.map do |grouped|
          { line_item: grouped.first[:line_item], quantity: grouped.sum { |item| item[:quantity].to_i } }
        end

        merged.each do |item|
          line_item = item[:line_item]
          quantity = item[:quantity]

          unless quantity.positive?
            return failure(nil, Spree.t('fulfillments.errors.invalid_quantity', item: line_item.prefixed_id))
          end

          available = available_for.call(line_item)
          if quantity > available
            return failure(
              nil,
              Spree.t('fulfillments.errors.insufficient_quantity',
                      item: line_item.prefixed_id, requested: quantity, available: available)
            )
          end
        end

        merged
      end

      # Moves the requested quantities into the fulfillment, on-hand units
      # first so the new fulfillment is shippable whenever possible. Restocks
      # the source location and unstocks the target for tracked variants when
      # the locations differ, keeping stock levels truthful about where the
      # goods actually leave from.
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
            source_shipments << unit.shipment
            stock_moves[[unit.shipment, unit.variant]] += take

            target = fulfillment.inventory_units.find_or_initialize_by(
              state: unit.state,
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

        stock_moves.each do |(source_shipment, variant), quantity|
          next unless variant.track_inventory?
          next if source_shipment.stock_location_id == fulfillment.stock_location_id

          source_shipment.stock_location.restock(variant, quantity, source_shipment)
          fulfillment.stock_location.unstock(variant, quantity, fulfillment)
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
          next unless shipment.inventory_units.sum(:quantity).zero?

          inherited[:cost] += shipment.cost
          inherited[:delivery_method] ||= shipment.shipping_method if capture_delivery_method
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
        fulfillment.add_shipping_method(method, true) if method
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
        return failure(nil, Spree.t('fulfillments.errors.invalid_cost')) if parsed.negative?

        parsed
      rescue ArgumentError
        failure(nil, Spree.t('fulfillments.errors.invalid_cost'))
      end

      # Registers an externally-completed fulfillment: backorders are filled
      # (the external location evidently had the goods) and the paid-order
      # readiness gate is bypassed deliberately — the goods already left.
      def mark_shipped(fulfillment)
        fulfillment.inventory_units.backordered.each(&:fill_backorder!)
        fulfillment.update_columns(state: 'ready') unless fulfillment.ready?
        fulfillment.reload.ship!
      end
    end
  end
end
