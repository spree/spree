module Spree
  module MaintenanceTasks
    module Upgrade
      # Fills the ISO country and state code columns from the legacy country and
      # state foreign keys (docs/plans/6.0-drop-country-state-models.md).
      #
      # Set-based by construction: each table is filled with one correlated
      # UPDATE scoped to rows whose code column is still null, so the work left
      # is a query and a re-run is a no-op.
      class CountryStateCodes < Spree::MaintenanceTask
        description 'maintenance_tasks.upgrade.country_state_codes.description'
        no_collection

        def process
          result = Spree::CountryStateCodeMigrator.new.call

          if result.nil?
            tally(:skipped_no_legacy_tables)
            return
          end

          result.each { |table, filled| tally(table, filled) }
        end
      end
    end
  end
end
