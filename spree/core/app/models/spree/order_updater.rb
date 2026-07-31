module Spree
  # @deprecated Removed in Spree 6.1. Every method is a thin shim over the
  #   flows that own the work:
  #
  #   * money    — {Spree::Carts::RecalculateTotals} /
  #                {Spree::Orders::RecalculateTotals} (or the model's
  #                +#recalculate_totals!+)
  #   * statuses — {Spree::Orders::UpdateStatuses} (or +#update_statuses!+),
  #                the sole writer of +payment_status+/+fulfillment_status+
  #
  #   The granular partial updates no longer exist as separate computations:
  #   the totals workflow is the single money seam, so each money shim runs
  #   the full recalculation.
  class OrderUpdater
    attr_reader :order
    delegate :payments, :line_items, :fulfillments, :update_hooks, :quantity, to: :order

    def initialize(order)
      @order = order
    end

    # @deprecated Use {Spree::Carts::RecalculateTotals} /
    #   {Spree::Orders::RecalculateTotals} (or +#recalculate_totals!+);
    #   removed in 6.1.
    def update
      deprecate_totals(__method__)
      recalculate_totals
      update_statuses if order.completed?
    end

    # @deprecated Use {Spree::Carts::RecalculateTotals}; removed in 6.1. The
    #   totals workflow rebuilds the typed adjustment rows as part of its
    #   money pass.
    def recalculate_adjustments
      deprecate_totals(__method__)
      recalculate_totals
    end

    # @deprecated Use {Spree::Carts::RecalculateTotals}; removed in 6.1.
    def update_totals
      deprecate_totals(__method__)
      recalculate_totals
    end

    # @deprecated Use {Spree::Carts::RecalculateTotals}; removed in 6.1.
    def update_payment_total
      deprecate_totals(__method__)
      recalculate_totals
      order.payment_total
    end

    # @deprecated Use {Spree::Carts::RecalculateTotals}; removed in 6.1.
    def update_item_total
      deprecate_totals(__method__)
      recalculate_totals
      order.item_total
    end

    # @deprecated Use {Spree::Carts::RecalculateTotals}; removed in 6.1.
    def update_order_total
      deprecate_totals(__method__)
      recalculate_totals
      order.total
    end

    # @deprecated Use {Spree::Carts::RecalculateTotals}; removed in 6.1.
    def update_adjustment_total
      deprecate_totals(__method__)
      recalculate_totals
      order.adjustment_total
    end

    # @deprecated Use {Spree::Carts::RecalculateTotals}; removed in 6.1.
    def update_item_count
      deprecate_totals(__method__)
      recalculate_totals
      order.total_quantity
    end

    # @deprecated Use {Spree::Carts::RecalculateTotals}; removed in 6.1.
    def persist_totals
      deprecate_totals(__method__)
      recalculate_totals
    end

    # @deprecated Use {Spree::Carts::RecalculateTotals}; removed in 6.1.
    def update_shipment_total
      Spree::Deprecation.warn('Spree::OrderUpdater#update_shipment_total is deprecated and will be removed in Spree 6.1. Use Spree::Carts::RecalculateTotals / Spree::Orders::RecalculateTotals (or #recalculate_totals!) instead.')
      recalculate_totals
      order.delivery_total
    end

    # @deprecated Use {Spree::Orders::UpdateStatuses} (or
    #   +#update_statuses!+); removed in 6.1. UpdateStatuses writes the 6.0
    #   vocabulary (none/authorized/partially_paid/paid/partially_refunded/
    #   refunded/overcharged/voided), not the legacy balance_due/credit_owed/
    #   failed/void names.
    def update_payment_state
      deprecate_statuses(__method__)
      update_statuses
      order.payment_status
    end

    # @deprecated Use {Spree::Orders::UpdateStatuses} (or
    #   +#update_statuses!+); removed in 6.1.
    def update_shipment_state
      deprecate_statuses(__method__)
      update_statuses
      order.fulfillment_status
    end

    # @deprecated Use {Spree::Orders::UpdateStatuses} for the state roll-up
    #   and {Spree::Carts::Recalculate} for the delivery proposal rebuild;
    #   removed in 6.1.
    def update_shipments
      Spree::Deprecation.warn('Spree::OrderUpdater#update_shipments is deprecated and will be removed in Spree 6.1. Use Spree::Orders::UpdateStatuses (fulfillment states) and Spree::Carts::Recalculate (delivery proposals) instead.')

      shipping_method_filter = order.completed? ? DeliveryMethod::DISPLAY_ON_BACK_END : DeliveryMethod::DISPLAY_ON_FRONT_END

      fulfillments.each do |fulfillment|
        next unless fulfillment.persisted?

        fulfillment.update!(order)
        next if order.completed? && fulfillment.fulfilled?

        fulfillment.refresh_rates(shipping_method_filter)
        fulfillment.update_amounts
      end
    end

    # @deprecated Order update hooks are removed in 6.1 — subscribe to the
    #   +order.updated+ event instead.
    def run_hooks
      Spree::Deprecation.warn('Spree::OrderUpdater#run_hooks is deprecated and will be removed in Spree 6.1. Subscribe to the order.updated event instead.')
      update_hooks.each { |hook| order.send hook }
    end

    private

    def recalculate_totals
      Spree.cart_recalculate_totals_workflow.call(cart: order)
    end

    # UpdateStatuses persists via update_columns, which leaves the in-memory
    # record stale — re-read just the two status columns it wrote. The
    # fulfillments cache is reset first: the roll-up reads that association,
    # and callers routinely hold one loaded before their own mutations.
    def update_statuses
      order.association(:fulfillments).reset if order.persisted?

      Spree.order_update_statuses_service.call(order: order)
      return unless order.persisted?

      statuses = order.class.where(id: order.id).pick(:payment_status, :fulfillment_status)
      return if statuses.nil?

      # write_attribute, not the setters — these columns are already
      # persisted, so they must not show up as unsaved changes.
      order.send(:write_attribute, :payment_status, statuses.first)
      order.send(:write_attribute, :fulfillment_status, statuses.last)
      order.send(:clear_attribute_changes, [:payment_status, :fulfillment_status])
    end

    def deprecate_totals(method_name)
      Spree::Deprecation.warn("Spree::OrderUpdater##{method_name} is deprecated and will be removed in Spree 6.1. Use Spree::Carts::RecalculateTotals / Spree::Orders::RecalculateTotals (or #recalculate_totals!) instead.")
    end

    def deprecate_statuses(method_name)
      Spree::Deprecation.warn("Spree::OrderUpdater##{method_name} is deprecated and will be removed in Spree 6.1. Use Spree::Orders::UpdateStatuses (or #update_statuses!) instead.")
    end
  end
end
