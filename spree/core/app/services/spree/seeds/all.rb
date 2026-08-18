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

            # additional data
            TaxCategories.call

            # store & channels
            Stores.call
            Channels.call
            # Roles are store-owned, so they can only be seeded once a store
            # exists — every store gets its own immutable admin role.
            Roles.call
            # Store-scoped, so it can only run once a store exists.
            DigitalDelivery.call
            # The warehouse, delivery zones and pickup are not seeded: their
            # shape depends on which country the shop sells from, and nobody
            # has answered that yet. Spree::Stores::ProvisionDefaults builds
            # them from the merchant's answer — at first-run setup, or here
            # when ADMIN_EMAIL/ADMIN_PASSWORD name an install that skips it.
            AdminUser.call

            # add store resources
            PaymentMethods.call
            TaxCategories.call
            ProductTypes.call
            CustomerGroups.call
            ReturnsEnvironment.call
            # The marketplace's catch-all rate, at the bottom of the list so
            # narrower rates added later resolve ahead of it.
            CommissionRates.call
            ApiKeys.call
            AllowedOrigins.call
          end
        end
      end
    end
  end
end
