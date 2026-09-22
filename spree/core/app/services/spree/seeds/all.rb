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

            Stores.call
            # Every store-scoped seed, across every store. They can only run
            # once a store exists.
            StoreResources::SEEDS.each(&:call)
            # The warehouse, delivery zones and pickup are not seeded: their
            # shape depends on which country the shop sells from, and nobody
            # has answered that yet. Spree::Stores::ProvisionDefaults builds
            # them from the merchant's answer — at first-run setup, or here
            # when ADMIN_EMAIL/ADMIN_PASSWORD name an install that skips it.
            # Runs last, so provisioning can restate the currency of the
            # digital delivery method seeded above.
            AdminUser.call
          end
        end
      end
    end
  end
end
