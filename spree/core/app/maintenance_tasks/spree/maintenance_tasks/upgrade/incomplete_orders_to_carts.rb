module Spree
  module MaintenanceTasks
    module Upgrade
      # Moves incomplete orders onto the Cart model that owns checkout in 6.0,
      # re-owning their line items and fulfillments.
      #
      # Set-based: the work is SQL over whole tables rather than a row walk, so
      # the run records what it did rather than progress through it.
      class IncompleteOrdersToCarts < RakeStep
        description 'maintenance_tasks.upgrade.incomplete_orders_to_carts.description'

        runs_rake_task 'spree:migrate_incomplete_orders_to_carts'
      end
    end
  end
end
