module Spree
  class OrderUpdater
    attr_reader :order
    delegate :payments, :line_items, :adjustments, :shipments, :update_hooks, :to => :order

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
      update_totals
      update_payment_state

      # give each of the shipments a chance to update themselves
      shipments.each { |shipment| shipment.update!(order) }#(&:update!)
      update_shipment_state
      update_adjustments
      # update totals a second time in case updated adjustments have an effect on the total
      update_totals

      order.update_attributes_without_callbacks({
        :payment_state => order.payment_state,
        :shipment_state => order.shipment_state,
        :item_total => order.item_total,
        :adjustment_total => order.adjustment_total,
        :payment_total => order.payment_total,
        :total => order.total
      })

      #ensure checkout payment always matches order total
      if order.payment and order.payment.checkout? and order.payment.amount != order.total
        order.payment.update_attributes_without_callbacks(:amount => order.total)
      end

      update_hooks.each { |hook| order.send hook }
    end

    # Updates the following Order total values:
    #
    # +payment_total+      The total value of all finalized Payments (NOTE: non-finalized Payments are excluded)
    # +item_total+         The total value of all LineItems
    # +adjustment_total+   The total value of all adjustments (promotions, credits, etc.)
    # +total+              The so-called "order total."  This is equivalent to +item_total+ plus +adjustment_total+.
    def update_totals
      order.payment_total = payments.completed.map(&:amount).sum
      order.item_total = line_items.map(&:amount).sum
      order.adjustment_total = adjustments.eligible.map(&:amount).sum
      order.total = order.item_total + order.adjustment_total
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
        order.shipment_state =
        case shipments.count
        when 0
          nil
        when shipments.shipped.count
          'shipped'
        when shipments.ready.count
          'ready'
        when shipments.pending.count
          'pending'
        else
          'partial'
        end
      end
      order.state_changed('shipment')
    end

    # Updates the +payment_state+ attribute according to the following logic:
    #
    # paid          when +payment_total+ is equal to +total+
    # balance_due   when +payment_total+ is less than +total+
    # credit_owed   when +payment_total+ is greater than +total+
    # failed        when most recent payment is in the failed state
    #
    # The +payment_state+ value helps with reporting, etc. since it provides a quick and easy way to locate Orders needing attention.
    def update_payment_state

      #line_item are empty when user empties cart
      if line_items.empty? || round_money(order.payment_total) < round_money(order.total)
        if payments.present? && payments.last.state == 'failed'
          order.payment_state = 'failed'
        else
          order.payment_state = 'balance_due'
        end
      elsif round_money(order.payment_total) > round_money(order.total)
        order.payment_state = 'credit_owed'
      else
        order.payment_state = 'paid'
      end

      order.state_changed('payment')
    end

    # Updates each of the Order adjustments.
    #
    # This is intended to be called from an Observer so that the Order can
    # respond to external changes to LineItem, Shipment, other Adjustments, etc.
    #
    # Adjustments will check if they are still eligible. Ineligible adjustments
    # are preserved but not counted towards adjustment_total.
    def update_adjustments
      order.adjustments.reload.each { |adjustment| adjustment.update!(order) }
    end
    

    private

      def round_money(n)
        (n * 100).round / 100.0
      end
  end
end
