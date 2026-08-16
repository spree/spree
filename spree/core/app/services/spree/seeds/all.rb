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
            Spree::Store.find_each { |store| StoreResources.call(store: store) }
            # The warehouse, delivery zones and pickup are not seeded: their
            # shape depends on which country the shop sells from, and nobody
            # has answered that yet. Spree::Stores::ProvisionDefaults builds
            # them from the merchant's answer — at first-run setup, or here
            # when ADMIN_EMAIL/ADMIN_PASSWORD name an install that skips it.
            AdminUser.call

            # A database created by today's schema has no historical data to
            # convert, so every upgrade boundary up to this release is already
            # satisfied. Recording that is what keeps a fresh install from
            # being shown a backlog of steps it must never run.
            stamp_upgrade_boundaries
          end
        end
      end

      private

      def stamp_upgrade_boundaries
        Spree::Upgrade.manifests.each do |manifest|
          Spree::UpgradeRecord.stamp!(manifest['to'], source: 'install')
        end
      end
    end
  end
end
