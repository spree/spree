module Spree
  module MaintenanceTasks
    module Upgrade
      # Gives imports and exports the store and author they were missing, so
      # each one lists for the store it was run against.
      class ImportExportTenancy < RakeStep
        description 'maintenance_tasks.upgrade.import_export_tenancy.description'

        runs_rake_task 'spree:upgrade:backfill_import_export_tenancy'
      end
    end
  end
end
