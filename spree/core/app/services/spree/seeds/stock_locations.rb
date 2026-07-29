module Spree
  module Seeds
    class StockLocations
      prepend Spree::ServiceModule::Base

      def call
        Spree::Store.all.find_each do |store|
          Spree::StockLocation.find_or_create_by!(
            store: store,
            name: Spree.t(:default_stock_location_name),
            propagate_all_variants: false,
            country: store.default_country,
            active: true,
            default: true
          )
        end
      end
    end
  end
end
