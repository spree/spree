module Spree
  module MaintenanceTasks
    module Upgrade
      # Binds product types to the default store, drops orphaned option-type joins
      # and resets product counters.
      #
      # Set-based: the work is SQL over whole tables rather than a row walk, so
      # the run records what it did rather than progress through it.
      class ProductTypes < RakeStep
        description 'maintenance_tasks.upgrade.product_types.description'

        runs_rake_task 'spree:product_types:backfill'
      end
    end
  end
end
