module Spree
  module Orders
    # Shared fulfillment-building step for admin order Create / Update.
    #
    # Rebuilds fulfillments from scratch (order routing), then layers in
    # tax, costs, and free-shipping promotions so totals reflect delivery
    # before payment is requested. Without this, draft orders would expose
    # delivery_total: 0.0 until completion is attempted — which is too late.
    #
    # No-op when the order has no shipping address, no line items, or does
    # not require delivery (digital orders, etc.).
    #
    # Also a no-op once the order is placed. Its fulfillments hold the stock
    # promised at placement, and an edit adjusts them in place through
    # Spree::OrderInventory. Rebuilding would delete them and leave that
    # promise on rows nothing can cancel or ship, so the stock stays held.
    class BuildFulfillments
      prepend Spree::ServiceModule::Base

      def call(order:)
        return success(order) if order.completed?
        return success(order) unless order.ship_address_id.present?
        return success(order) unless order.line_items.any?
        return success(order) unless order.delivery_step_required?

        order.rebuild_fulfillments!
        order.create_shipment_tax_charge!
        order.set_fulfillments_cost
        order.apply_free_shipping_promotions

        success(order)
      end
    end
  end
end
