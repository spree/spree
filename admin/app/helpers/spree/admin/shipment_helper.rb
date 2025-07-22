module Spree::Admin
  module ShipmentHelper
    include Spree::ShipmentHelper

    def can_ship?(shipment)
      can?(:update, shipment) && shipment.shippable?
    end

    def stock_locations_for_split(variant)
      available_stock_locations.
        joins(:stock_items).
        where(spree_stock_items: { variant_id: variant.id }).
        group(:id).
        pluck(:name, "sum(spree_stock_items.count_on_hand)", :id).
        map { |name, count, id| ["#{name.capitalize} (#{count} on hand)", "stock-location_#{id}"] }
    end

    def shipments_for_transfer(current_shipment)
      current_shipment.
        order.
        shipments.
        ready_or_pending.
        where(stock_location: available_stock_locations).
        where.not(id: current_shipment.id).
        pluck(:number, :id).
        map { |n, i| [n, "shipment_#{i}"] }
    end
  end
end
