module Spree
  module Seeds
    # Seeds only what has no Admin API by design: the store row, its immutable
    # admin role, its first publishable key and, when ADMIN_EMAIL and
    # ADMIN_PASSWORD are set, the first admin (otherwise first-run setup
    # creates it). Everything a
    # store trades with — tax categories, channels, reasons, the warehouse,
    # delivery zones — is the seeds engine's store defaults, deployed once the
    # store knows where it sells from (docs/plans/6.0-cli-configurator.md).
    class All
      prepend Spree::ServiceModule::Base

      def call
        Spree::Events.disable do
          ActiveRecord::Base.no_touching do
            fresh_database = Spree::Store.none?

            Stores.call
            Roles.call
            ApiKeys.call
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
