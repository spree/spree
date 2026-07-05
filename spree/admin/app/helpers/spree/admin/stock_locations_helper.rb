module Spree
  module Admin
    module StockLocationsHelper
      def available_stock_locations(_opts = {})
        Spree::StockLocation.order_default.active.accessible_by(current_ability)
      end

      def available_stock_locations_list(opts = {})
        available_stock_locations(opts).map { |stock_location| [stock_location.display_name, stock_location.id] }
      end

      # overwrite this to customize behavior
      def available_stock_locations_for_product(_product)
        available_stock_locations
      end

      def default_stock_location_for_product(_product)
        current_store.default_stock_location
      end
    end
  end
end
