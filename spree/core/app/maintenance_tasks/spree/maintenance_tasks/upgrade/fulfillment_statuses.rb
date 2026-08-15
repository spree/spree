module Spree
  module MaintenanceTasks
    module Upgrade
      # Collapses the fulfillment status vocabulary onto the 6.0 set and recomputes
      # each affected order's rollup.
      #
      # Set-based: the work is SQL over whole tables rather than a row walk, so
      # the run records what it did rather than progress through it.
      class FulfillmentStatuses < RakeStep
        description 'maintenance_tasks.upgrade.fulfillment_statuses.description'

        runs_rake_task 'spree:migrate_fulfillment_statuses'
      end
    end
  end
end
