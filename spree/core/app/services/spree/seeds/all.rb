module Spree
  module Seeds
    class All
      prepend Spree::ServiceModule::Base

      def call
        Spree::Events.disable do
          ActiveRecord::Base.no_touching do
            # GEO — countries and states are reference data supplied by the
            # countries gem, and zones are migration-only, so none of them
            # are seeded.

            # user roles
            Roles.call

            # additional data
            StoreCreditCategories.call
            TaxCategories.call

            # store & stock location
            Stores.call
            Channels.call
            StockLocations.call
            DeliveryZones.call
            # Store-scoped, so they can only run once a store and its
            # locations exist.
            DigitalDelivery.call
            PickupDelivery.call
            AdminUser.call

            # add store resources
            PaymentMethods.call
            TaxCategories.call
            ProductTypes.call
            CustomerGroups.call
            ReturnsEnvironment.call
            ApiKeys.call
            AllowedOrigins.call
          end
        end
      end
    end
  end
end
