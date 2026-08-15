module Spree
  module MaintenanceTasks
    module Upgrade
      # Maps legacy adjustments onto the typed tax line, discount and fee tables
      # without touching order totals, freezing orders that do not reconcile.
      #
      # Set-based: the work is SQL over whole tables rather than a row walk, so
      # the run records what it did rather than progress through it.
      class AdjustmentsToTypedRows < RakeStep
        description 'maintenance_tasks.upgrade.adjustments_to_typed_rows.description'

        runs_rake_task 'spree:migrate_adjustments_to_typed_rows'
      end
    end
  end
end
