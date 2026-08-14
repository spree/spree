module Spree
  module Seeds
    class StockLocations
      prepend Spree::ServiceModule::Base

      def call
        Spree::Store.all.find_each do |store|
          # Match on identity alone. Folding the other attributes into the
          # finder made re-seeding fail once anything edited them (the pickup
          # seed enabling collection, a merchant flipping a flag): the lookup
          # missed the existing row and tried to create a duplicate name.
          Spree::StockLocation.where(
            store: store,
            name: Spree.t(:default_stock_location_name)
          ).first_or_create! do |stock_location|
            stock_location.propagate_all_variants = false
            stock_location.country_iso = store.default_country&.iso
            stock_location.active = true
            stock_location.default = true
          end
        end
      end
    end
  end
end
