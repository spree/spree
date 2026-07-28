module Spree
  class OrderUpdater
    attr_reader :order
    delegate :payments, :line_items, :adjustments, :all_adjustments, :fulfillments, :update_hooks, :quantity, to: :order

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

    def recalculate_adjustments
      all_adjustments.includes(:adjustable).map(&:adjustable).uniq.each do |adjustable|
        Adjustable::AdjustmentsUpdater.update(adjustable)
      end
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

    # give each of the fulfillments a chance to update themselves
    def update_fulfillments
      shipping_method_filter = order.completed? ? DeliveryMethod::DISPLAY_ON_BACK_END : DeliveryMethod::DISPLAY_ON_FRONT_END

      fulfillments.each do |shipment|
        next unless shipment.persisted?

        shipment.update!(order)
        shipment.refresh_rates(shipping_method_filter)
        shipment.update_amounts
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
      shipment_totals = fulfillments.reorder(nil).pick(
        Arel.sql('COALESCE(SUM(adjustment_total), 0)'),
        Arel.sql('COALESCE(SUM(included_tax_total), 0)'),
        Arel.sql('COALESCE(SUM(additional_tax_total), 0)'),
        Arel.sql('COALESCE(SUM(promo_total), 0)')
      ) || [0, 0, 0, 0]

      # Fetch order-level adjustment totals in a single query
      order_adjustment_totals = adjustments.eligible.reorder(nil).pick(
        Arel.sql('COALESCE(SUM(amount), 0)'),
        Arel.sql("COALESCE(SUM(CASE WHEN source_type = 'Spree::PromotionAction' THEN amount ELSE 0 END), 0)")
      ) || [0, 0]

      order.adjustment_total = line_item_totals[0] + shipment_totals[0] + order_adjustment_totals[0]
      order.included_tax_total = line_item_totals[1] + shipment_totals[1]
      order.additional_tax_total = line_item_totals[2] + shipment_totals[2]
      order.promo_total = line_item_totals[3] + shipment_totals[3] + order_adjustment_totals[1]

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
        payment_total: order.payment_total,
        delivery_total: order.delivery_total,
        promo_total: order.promo_total,
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

      order.state_changed('shipment')
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
