module Spree
  class OrderUpdater
    attr_reader :order
    delegate :payments, :line_items, :fulfillments, :update_hooks, :quantity, to: :order

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
      # Drop possibly stale association caches — an earlier recalculation on
      # this instance may have loaded them mid-mutation.
      order.association(:line_items).reset if order.persisted?
      order.association(:fulfillments).reset if order.persisted?

      update_item_count
      update_totals
      if order.completed?
        update_payment_state
        update_fulfillments
        update_fulfillment_status
        update_delivery_total
      end
      run_hooks
      persist_totals
    end

    def run_hooks
      update_hooks.each { |hook| order.send hook }
    end

    # Rebuilds the typed adjustment rows (Discount/Fee via Spree.adjusters,
    # TaxLine via Spree.tax_provider) and refreshes the denormalized columns
    # on line items and fulfillments. Two-pass: adjusters persist the
    # discounted taxable base first, then tax is estimated on it.
    #
    # Completed orders are frozen — recalculation refuses to touch them.
    # Post-placement changes go through explicit admin actions that write
    # typed rows directly and recompute totals via {#update}.
    def recalculate_adjustments
      return if order.completed?

      Spree.adjusters.each { |adjuster| adjuster.adjust(order) }
      refresh_discount_and_fee_columns
      Spree.tax_provider.estimate(order)
      refresh_tax_columns
    end

    # Updates the following Order total values:
    #
    # +payment_total+      The total value of all finalized Payments (NOTE: non-finalized Payments are excluded)
    # +item_total+         The total value of all LineItems
    # +adjustment_total+   The total value of all typed adjustment rows (discounts, fees, additional tax)
    # +promo_total+        The total value of all promotion discounts
    # +fee_total+          The total value of all fees
    # +total+              The so-called "order total." Equivalent to +item_total+ plus +delivery_total+ plus +adjustment_total+.
    def update_totals
      update_payment_total
      update_item_total
      update_delivery_total
      update_adjustment_total
    end

    # give each of the fulfillments a chance to update themselves.
    # Completed orders only recompute statuses — repricing a completed
    # order's delivery would break the money freeze.
    def update_fulfillments
      shipping_method_filter = order.completed? ? DeliveryMethod::DISPLAY_ON_BACK_END : DeliveryMethod::DISPLAY_ON_FRONT_END

      fulfillments.each do |fulfillment|
        next unless fulfillment.persisted?

        fulfillment.update!(order)
        next if order.completed? && fulfillment.fulfilled?

        fulfillment.refresh_rates(shipping_method_filter)
        fulfillment.update_amounts
      end
    end

    def update_payment_total
      order.payment_total = payments.completed.includes(:refunds).inject(0) { |sum, payment| sum + payment.amount - payment.refunds.sum(:amount) }
    end

    def update_delivery_total
      order.delivery_total = fulfillments.to_a.sum(&:cost)
      update_order_total
    end

    def update_order_total
      order.total = order.item_total + order.delivery_total + order.adjustment_total
    end

    # Aggregates order totals from the typed tables. On completed orders the
    # stored sums are left untouched (the recalculation freeze) — only the
    # roll-up total is refreshed from its parts.
    def update_adjustment_total
      if order.completed?
        update_order_total
        return
      end

      recalculate_adjustments

      discounts_sum = order.discounts.reload.sum(&:amount)
      fees = order.fees.reload.to_a
      tax_sums = order.tax_lines.reload.group_by(&:included?).transform_values { |lines| lines.sum(&:amount) }

      order.promo_total = order.discounts.select(&:promotion?).sum(&:amount)
      order.fee_total = fees.sum(&:amount)
      order.included_tax_total = tax_sums.fetch(true, 0)
      order.additional_tax_total = tax_sums.fetch(false, 0)
      order.adjustment_total = discounts_sum + order.fee_total + order.additional_tax_total

      # The order's own adjustable columns cover order-level rows only:
      # discounts distribute to line items, so fees are the only residents.
      order.taxable_adjustment_total = 0
      order.non_taxable_adjustment_total = fees.select(&:order_level?).sum(&:amount)

      update_order_total
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
        payment_status: order.payment_status,
        fulfillment_status: order.fulfillment_status,
        item_total: order.item_total,
        item_count: order.item_count,
        adjustment_total: order.adjustment_total,
        included_tax_total: order.included_tax_total,
        additional_tax_total: order.additional_tax_total,
        taxable_adjustment_total: order.taxable_adjustment_total,
        non_taxable_adjustment_total: order.non_taxable_adjustment_total,
        payment_total: order.payment_total,
        delivery_total: order.delivery_total,
        promo_total: order.promo_total,
        fee_total: order.fee_total,
        total: order.total,
        updated_at: Time.current
      )
    end

    # Updates the +fulfillment_status+ attribute according to the following logic:
    #
    # fulfilled when all Fulfillments are in the "fulfilled" status
    # partial   when at least one Fulfillment is "fulfilled" and there is another
    #           Fulfillment with a status other than "fulfilled"
    # ready     when all Fulfillments are "ready" (ready_for_pickup rolls up as ready)
    # backorder when there is backordered inventory associated with an order
    # pending   when all Fulfillments are "pending"
    #
    # The +fulfillment_status+ value helps with reporting, etc. since it provides a quick and easy way to locate Orders needing attention.
    def update_fulfillment_status
      if order.backordered?
        order.fulfillment_status = 'backorder'
      else
        # ready_for_pickup is customer-actionable on the fulfillment itself but
        # rolls up as ready at the order level
        statuses = fulfillments.states.uniq.map { |status| status == 'ready_for_pickup' ? 'ready' : status }.uniq

        order.fulfillment_status = if statuses.size > 1
                                     if statuses.include?('fulfilled')
                                       'partial'
                                     elsif statuses.include?('pending')
                                       'pending'
                                     else
                                       'ready'
                                     end
                                   else
                                     # will return nil if no fulfillments are found
                                     statuses.first
                                   end
      end

      order.fulfillment_status
    end
    # @deprecated Use {#update_fulfillment_status}; removed in 6.1.
    def update_shipment_state
      Spree::Deprecation.warn('Spree::OrderUpdater#update_shipment_state is deprecated and will be removed in Spree 6.1. Use #update_fulfillment_status instead.')
      update_fulfillment_status
    end

    # @deprecated Use {#update_delivery_total}; removed in 6.1.
    def update_shipment_total
      Spree::Deprecation.warn('Spree::OrderUpdater#update_shipment_total is deprecated and will be removed in Spree 6.1. Use #update_delivery_total instead.')
      update_delivery_total
    end

    # @deprecated Use {#update_fulfillments}; removed in 6.1.
    def update_shipments
      Spree::Deprecation.warn('Spree::OrderUpdater#update_shipments is deprecated and will be removed in Spree 6.1. Use #update_fulfillments instead.')
      update_fulfillments
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
      if payments.present? && payments.valid.empty?
        order.payment_state = 'failed'
      elsif order.canceled? && order.payment_total == 0
        order.payment_state = 'void'
      else
        order.payment_state = 'balance_due' if order.outstanding_balance > 0
        order.payment_state = 'credit_owed' if order.outstanding_balance < 0
        order.payment_state = 'paid' unless order.outstanding_balance?
      end
      order.payment_state
    end

    private

    # Pass one of the two-pass recalculation: persist per-adjustable discount
    # and fee sums so the tax provider estimates on the discounted base.
    def refresh_discount_and_fee_columns
      discounts = order.discounts.reload.to_a
      fees = order.fees.reload.to_a

      each_adjustable do |adjustable, key|
        rows = discounts.select { |row| row.public_send(key) == adjustable.id }
        fee_rows = fees.select { |row| row.public_send(key) == adjustable.id }

        update_adjustable_columns(
          adjustable,
          taxable_adjustment_total: rows.sum(&:amount),
          non_taxable_adjustment_total: fee_rows.sum(&:amount),
          promo_total: rows.select(&:promotion?).sum(&:amount)
        )
      end
    end

    # Pass two: fold the freshly estimated tax into the per-adjustable columns.
    def refresh_tax_columns
      tax_lines = order.tax_lines.reload.to_a

      each_adjustable do |adjustable, key|
        rows = tax_lines.select { |row| row.public_send(key) == adjustable.id }
        included, additional = rows.partition(&:included?)

        update_adjustable_columns(
          adjustable,
          included_tax_total: included.sum(&:amount),
          additional_tax_total: additional.sum(&:amount),
          adjustment_total: adjustable.taxable_adjustment_total +
            adjustable.non_taxable_adjustment_total +
            additional.sum(&:amount)
        )
      end
    end

    def each_adjustable
      line_items.each { |line_item| yield line_item, :line_item_id }
      fulfillments.each { |fulfillment| yield fulfillment, :fulfillment_id }
    end

    def update_adjustable_columns(adjustable, attributes)
      return unless adjustable.persisted?
      return if attributes.all? { |key, value| adjustable.public_send(key) == value }

      adjustable.update_columns(attributes.merge(updated_at: Time.current))
    end
  end
end
