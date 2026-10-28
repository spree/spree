module Spree
  module MaintenanceTasks
    module Upgrade
      # 5.6 → 6.0 conversion of store time zones saved as Rails display names
      # ("Eastern Time (US & Canada)") into IANA identifiers
      # ("America/New_York"), the only form the API accepts and browsers read.
      class StoreTimeZones < Spree::MaintenanceTask
        supports_dry_run

        def collection
          Spree::Store.with_deleted.order(:id)
        end

        def process(store)
          stored = store.preferred_timezone
          return if Spree::TimeZones.valid?(stored)

          time_zone = Spree::TimeZones.normalize(stored)
          return tally(:unknown) unless Spree::TimeZones.valid?(time_zone)
          return tally(:would_convert) if dry_run?

          store.preferred_timezone = time_zone
          store.update_columns(preferences: store.preferences, updated_at: Time.current)
          tally(:converted)
        end
      end
    end
  end
end
