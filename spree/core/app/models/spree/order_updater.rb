module Spree
  class OrderUpdater
    attr_reader :order
    delegate :payments, :line_items, :adjustments, :all_adjustments, :shipments, :update_hooks, :quantity, to: :order

    def initialize(order)
      @order = order
    end

    # This is a multi-purpose method for processing logic related to changes in the Order.
    # It is meant to be called from various observers so that the Order is aware of changes
    # that affect totals and other values stored in the Order.
    #
    # This method should never do anything to the Order that results in a save call on the
    # object with callbacks (otherwise you will end up in an infinite recursion as the
    # associations try to save and then in turn try to call +update!+ again.)
    def update
      update_item_count
      update_totals
      if order.completed?
        update_payment_state
        update_shipments
        update_shipment_state
        update_shipment_total
      end
      run_hooks
      persist_totals
    end

    def run_hooks
      update_hooks.each { |hook| order.send hook }
    end

    # The recalculation pipeline: adjusters run partitioned by their declared
    # type — discounts, then fees, then tax last (tax reads the discounted
    # basis). Registration order in Spree.adjusters only matters within a
    # type. One batched preload serves the whole run; adjusters mutate typed
    # adjustment lines in memory and the per-adjustable totals are rolled up
    # afterwards.
    #
    # Completed orders are never recalculated — their adjustment lines are
    # immutable by convention (the replacement for the old open/closed
    # adjustment state machine).
    def recalculate_adjustments
      return if order.completed?

      adjustables = order.line_items.includes(:fees, discount_lines: [:promotion, :promotion_action]).to_a +
                    order.shipments.includes(:fees, discount_lines: [:promotion, :promotion_action]).to_a

      discount_adjusters, fee_adjusters, tax_adjusters =
        Spree.adjusters.group_by(&:type).values_at(:discount, :fee, :tax)

      [*discount_adjusters, *fee_adjusters, *tax_adjusters].each do |adjuster|
        adjuster.adjust_all(order, adjustables)
      end

      persist_adjustable_totals(adjustables)
    end

    # Updates the following Order total values:
    #
    # +payment_total+      The total value of all finalized Payments (NOTE: non-finalized Payments are excluded)
    # +item_total+         The total value of all LineItems
    # +adjustment_total+   The total value of all adjustments (promotions, credits, etc.)
    # +promo_total+        The total value of all promotion adjustments
    # +total+              The so-called "order total."  This is equivalent to +item_total+ plus +shipment_total+ plus +adjustment_total+.
    def update_totals
      update_payment_total
      update_item_total
      update_shipment_total
      update_adjustment_total
    end

    # give each of the shipments a chance to update themselves
    def update_shipments
      shipping_method_filter = order.completed? ? ShippingMethod::DISPLAY_ON_BACK_END : ShippingMethod::DISPLAY_ON_FRONT_END

      shipments.each do |shipment|
        next unless shipment.persisted?

        shipment.update!(order)
        shipment.refresh_rates(shipping_method_filter)
        shipment.update_amounts
      end
    end

    def update_payment_total
      order.payment_total = payments.completed.includes(:refunds).inject(0) { |sum, payment| sum + payment.amount - payment.refunds.sum(:amount) }
    end

    def update_shipment_total
      order.shipment_total = shipments.to_a.sum(&:cost)
      update_order_total
    end

    def update_order_total
      order.total = order.item_total + order.shipment_total + order.adjustment_total
    end

    def update_adjustment_total
      recalculate_adjustments

      # Fetch all line item totals in a single query
      # Use reorder(nil) to remove default ordering which conflicts with aggregates in PostgreSQL
      line_item_totals = line_items.reorder(nil).pick(
        Arel.sql('COALESCE(SUM(adjustment_total), 0)'),
        Arel.sql('COALESCE(SUM(included_tax_total), 0)'),
        Arel.sql('COALESCE(SUM(additional_tax_total), 0)'),
        Arel.sql('COALESCE(SUM(promo_total), 0)')
      ) || [0, 0, 0, 0]

      # Fetch all shipment totals in a single query
      shipment_totals = shipments.reorder(nil).pick(
        Arel.sql('COALESCE(SUM(adjustment_total), 0)'),
        Arel.sql('COALESCE(SUM(included_tax_total), 0)'),
        Arel.sql('COALESCE(SUM(additional_tax_total), 0)'),
        Arel.sql('COALESCE(SUM(promo_total), 0)')
      ) || [0, 0, 0, 0]

      # There are no order-level adjustment rows anymore: whole-order
      # discounts are distributed to line items, fees and taxes are always
      # line-item- or fulfillment-attached.
      order.adjustment_total = line_item_totals[0] + shipment_totals[0]
      order.included_tax_total = line_item_totals[1] + shipment_totals[1]
      order.additional_tax_total = line_item_totals[2] + shipment_totals[2]
      order.promo_total = line_item_totals[3] + shipment_totals[3]
      order.fee_total = Spree::Fee.where(order_id: order.id).sum(:amount)

      update_order_total
    end

    # Rolls the typed adjustment lines up into each adjustable's denormalized
    # total columns (four grouped aggregate queries for the whole order, then
    # write-on-change). taxable_adjustment_total / non_taxable_adjustment_total
    # are no longer written — retired, dropped in 6.1.
    def persist_adjustable_totals(adjustables)
      discount_sums = Spree::DiscountLine.where(order_id: order.id).group(:line_item_id, :fulfillment_id).sum(:amount)
      fee_sums = Spree::Fee.where(order_id: order.id).group(:line_item_id, :fulfillment_id).sum(:amount)
      included_tax_sums = Spree::TaxLine.where(order_id: order.id).included_in_price
                                        .group(:line_item_id, :fulfillment_id).sum(:amount)
      additional_tax_sums = Spree::TaxLine.where(order_id: order.id).additional
                                          .group(:line_item_id, :fulfillment_id).sum(:amount)

      adjustables.each do |adjustable|
        key = adjustable.is_a?(Spree::LineItem) ? [adjustable.id, nil] : [nil, adjustable.id]

        promo_total = discount_sums[key] || 0
        additional_tax_total = additional_tax_sums[key] || 0
        attributes = {
          promo_total: promo_total,
          included_tax_total: included_tax_sums[key] || 0,
          additional_tax_total: additional_tax_total,
          adjustment_total: promo_total + (fee_sums[key] || 0) + additional_tax_total
        }

        changed = attributes.reject { |attribute, value| adjustable.read_attribute(attribute) == value }
        next if changed.empty?

        adjustable.update_columns(changed.merge(updated_at: Time.current))
      end
    end

    def update_item_count
      order.item_count = quantity
    end

    def update_item_total
      order.item_total = line_items.to_a.sum(&:amount)
      update_order_total
    end

    def persist_totals
      order.update_columns(
        payment_state: order.payment_state,
        shipment_state: order.shipment_state,
        item_total: order.item_total,
        item_count: order.item_count,
        adjustment_total: order.adjustment_total,
        included_tax_total: order.included_tax_total,
        additional_tax_total: order.additional_tax_total,
        payment_total: order.payment_total,
        shipment_total: order.shipment_total,
        promo_total: order.promo_total,
        fee_total: order.fee_total,
        total: order.total,
        updated_at: Time.current
      )
    end

    # Updates the +shipment_state+ attribute according to the following logic:
    #
    # shipped   when all Shipments are in the "shipped" state
    # partial   when at least one Shipment has a state of "shipped" and there is another Shipment with a state other than "shipped"
    #           or there are InventoryUnits associated with the order that have a state of "sold" but are not associated with a Shipment.
    # ready     when all Shipments are in the "ready" state
    # backorder when there is backordered inventory associated with an order
    # pending   when all Shipments are in the "pending" state
    #
    # The +shipment_state+ value helps with reporting, etc. since it provides a quick and easy way to locate Orders needing attention.
    def update_shipment_state
      if order.backordered?
        order.shipment_state = 'backorder'
      else
        # get all the shipment states for this order
        shipment_states = shipments.states.uniq

        order.shipment_state = if shipment_states.size > 1
                                 if shipment_states.include?('shipped')
                                   'partial'
                                 elsif shipment_states.include?('pending')
                                   'pending'
                                 else
                                   'ready'
                                 end
                               else
                                 # will return nil if no shipments are found
                                 shipment_states.first
                                 # TODO: inventory unit states?
                                 # if order.shipment_state && order.inventory_units.where(shipment_id: nil).exists?
                                 #   shipments exist but there are unassigned inventory units
                                 #   order.shipment_state = 'partial'
                                 # end
                               end
      end

      order.state_changed('shipment')
      order.shipment_state
    end

    # Updates the +payment_state+ attribute according to the following logic:
    #
    # paid          when +payment_total+ is equal to +total+
    # balance_due   when +payment_total+ is less than +total+
    # credit_owed   when +payment_total+ is greater than +total+
    # failed        when most recent payment is in the failed state
    # void          when order is canceled and +payment_total+ is equal to zero
    #
    # The +payment_state+ value helps with reporting, etc. since it provides a quick and easy way to locate Orders needing attention.
    def update_payment_state
      last_state = order.payment_state
      if payments.present? && payments.valid.empty?
        order.payment_state = 'failed'
      elsif order.canceled? && order.payment_total == 0
        order.payment_state = 'void'
      else
        order.payment_state = 'balance_due' if order.outstanding_balance > 0
        order.payment_state = 'credit_owed' if order.outstanding_balance < 0
        order.payment_state = 'paid' unless order.outstanding_balance?
      end
      order.state_changed('payment') if last_state != order.payment_state
      order.payment_state
    end
  end
end
