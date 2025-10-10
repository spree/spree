module Spree
  module Seeds
    class StockLocations
      prepend Spree::ServiceModule::Base

      def call
        country = Spree::Store.default.default_country
        Spree::StockLocation.find_or_create_by!(
          name: Spree.t(:default_stock_location_name),
          propagate_all_variants: false,
          country: country,
          active: true,
          default: true
        )
      end
    end
  end
end
