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

            fresh_database = Spree::Store.none?

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
            # being shown a backlog of steps it must never run. Only a database
            # seeded for the first time qualifies: seeding is also a deploy
            # step, and an upgraded store seeded before its upgrade ran still
            # has every step to do.
            stamp_upgrade_boundaries if fresh_database
          end
        end
      end

      private

      def stamp_upgrade_boundaries
        Spree::Upgrade.manifests.each do |manifest|
          Spree::UpgradeRecord.find_or_create_by!(version: manifest['to']) do |record|
            record.source = 'install'
            record.completed_at = Time.current
          end
        end
      end
    end
  end
end
