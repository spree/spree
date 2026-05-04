module Spree
  module Orders
    # Shared shipment-building step for admin order Create / Update.
    #
    # Rebuilds shipments from scratch (Stock::Coordinator), then layers in
    # tax, costs, and free-shipping promotions so totals reflect delivery
    # before payment is requested. Without this, draft orders would expose
    # delivery_total: 0.0 until completion is attempted — which is too late.
    #
    # No-op when the order has no shipping address, no line items, or does
    # not require delivery (digital orders, etc.).
    class BuildShipments
      prepend Spree::ServiceModule::Base

      def call(order:)
        return success(order) unless order.ship_address_id.present?
        return success(order) unless order.line_items.any?
        return success(order) unless order.delivery_required?

        order.create_proposed_shipments
        order.create_shipment_tax_charge!
        order.set_shipments_cost
        order.apply_free_shipping_promotions

        success(order)
      end
    end
  end
end
