class OrderUpdater
  attr_accessor :order

  def initialize(order)
    @order = order
  end

  # This is a multi-purpose method for processing logic related to changes in the Order.  It is meant to be called from
  # various observers so that the Order is aware of changes that affect totals and other values stored in the Order.
  # This method should never do anything to the Order that results in a save call on the object (otherwise you will end
  # up in an infinite recursion as the associations try to save and then in turn try to call +update!+ again.)
  def update!
    # TODO: I don't think we need this first update_totals call
    update_totals
    update_payment_state
    update_shipments
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

    ensure_correct_payment_total

    order.update_hooks.each { |hook| order.send hook }
  end

  # Updates the following Order total values:
  #
  # +payment_total+      The total value of all finalized Payments (NOTE: non-finalized Payments are excluded)
  # +item_total+         The total value of all LineItems
  # +adjustment_total+   The total value of all adjustments (promotions, credits, etc.)
  # +total+              The so-called "order total."  This is equivalent to +item_total+ plus +adjustment_total+.
  def update_totals
    # update_adjustments
    order.payment_total = order.completed_payment_total
    order.item_total = order.line_item_total
    order.adjustment_total = order.eligible_adjustments_total
    order.total = order.item_total + order.adjustment_total
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
    if order.line_items.empty? || round_money(order.payment_total) < round_money(order.total)
      if order.last_payment_failed?
        order.payment_state = 'failed'
      else
        order.payment_state = 'balance_due'
      end
    elsif round_money(order.payment_total) > round_money(order.total)
      order.payment_state = 'credit_owed'
    else
      order.payment_state = 'paid'
    end

    if old_payment_state = order.changed_attributes['payment_state']
      order.state_changes.create({
        :previous_state => old_payment_state,
        :next_state     => order.payment_state,
        :name           => 'payment',
        :user_id        => (User.respond_to?(:current) && User.current && User.current.id) || order.user_id
      }, :without_protection => true)
    end
  end

  def update_shipments
    # give each of the shipments a chance to update themselves
    order.shipments.each { |shipment| shipment.update!(order) }#(&:update!)
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
      order.shipment_state 'backorder'
    else
      order.shipment_state =
        case order.shipments.count
        when 0
          nil
        when order.shipments.shipped.count
          'shipped'
        when order.shipments.ready.count
          'ready'
        when order.shipments.pending.count
          'pending'
        else
          'partial'
        end
    end

    if old_shipment_state = order.changed_attributes['shipment_state']
      order.state_changes.create({
        :previous_state => old_shipment_state,
        :next_state     => order.shipment_state,
        :name           => 'shipment',
        :user_id        => (User.respond_to?(:current) && User.current && User.current.id) || order.user_id
      }, :without_protection => true)
    end
  end

  # Updates each of the Order adjustments.  This is intended to be called from an Observer so that the Order can
  # respond to external changes to LineItem, Shipment, other Adjustments, etc.
  # Adjustments will check if they are still eligible. Ineligible adjustments are preserved but not counted
  # towards adjustment_total.
  def update_adjustments
    order.adjustments.reload.each { |adjustment| adjustment.update!(order) }
  end

  def ensure_correct_payment_total
    #ensure checkout payment always matches order total
    if order.payment and order.payment.checkout? and order.payment.amount != order.total
      order.payment.update_column(:amount, order.total)
    end
  end

  private

  def round_money(n)
    (n*100).round / 100.0
  end
end
