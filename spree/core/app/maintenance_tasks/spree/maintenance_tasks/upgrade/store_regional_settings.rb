module Spree
  module MaintenanceTasks
    module Upgrade
      # 5.6 → 6.0 conversion of the store's time zone into an IANA identifier
      # ("Eastern Time (US & Canada)" becomes "America/New_York") and of its
      # admin language into a listed locale code (`en_US` becomes `en-US`), the
      # only forms the API accepts and browsers read.
      #
      # A time zone that names no zone falls back to the store default, which is
      # what the store already ran on: Ruby could not read it either. An admin
      # language Spree does not list is cleared, so the dashboard shows each
      # staff member their own language.
      class StoreRegionalSettings < Spree::MaintenanceTask
        supports_dry_run

        def collection
          Spree::Store.with_deleted.order(:id)
        end

        def process(store)
          changes = time_zone_change(store).merge(admin_locale_change(store))
          return if changes.empty?

          changes.each_value { |outcome, _value| tally(dry_run? ? :"would_#{outcome}" : outcome) }
          return if dry_run?

          changes.each { |name, (_outcome, value)| store.set_preference(name, value) }
          store.update_columns(preferences: store.preferences, updated_at: Time.current)
        end

        private

        def time_zone_change(store)
          stored = store.preferred_timezone
          return {} if Spree::TimeZones.valid?(stored)

          converted = Spree::TimeZones.normalize(stored)
          return { timezone: [:time_zone_converted, converted] } if Spree::TimeZones.valid?(converted)

          { timezone: [:time_zone_reset_to_default, store.preference_default(:timezone)] }
        end

        def admin_locale_change(store)
          stored = store.preferred_admin_locale
          return {} if stored.blank? || Spree::Locales::ALL.include?(stored)

          listed = Spree::Locales.listed(stored)
          { admin_locale: listed ? [:admin_locale_converted, listed] : [:admin_locale_cleared, nil] }
        end
      end
    end
  end
end
