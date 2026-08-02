module Spree
  module FulfillmentProvider
    # Merchant-location pickup: hand-over is confirmed by staff, no
    # provider-side mechanics.
    class Pickup < Base
      def self.fulfillment_types
        ['pickup']
      end

      def requires_address?
        false
      end

      # A pickup rate is only real when the package can reach a counter the
      # customer may collect from: either the package is sourced from an
      # eligible pickup location itself, or some eligible location accepts
      # remote stock (pickup_stock_policy 'any' — ship-to-store transfers).
      def serves_location?(delivery_method, stock_location)
        return false if stock_location.nil?

        stock_locations = Spree::StockLocation.arel_table
        delivery_method.available_pickup_locations.where(
          stock_locations[:id].eq(stock_location.id).or(
            stock_locations[:pickup_stock_policy].eq('any')
          )
        ).exists?
      end

      def create_fulfillment(_fulfillment)
        {}
      end

      def cancel_fulfillment(_fulfillment)
        true
      end
    end
  end
end
