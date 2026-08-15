module Spree
  module MaintenanceTasks
    module Upgrade
      # Retires the hidden master variant: simple products' masters become regular
      # variants, ghost masters are removed, and variant counts are recomputed.
      #
      # Set-based: the work is SQL over whole tables rather than a row walk, so
      # the run records what it did rather than progress through it.
      class RemoveMasterVariant < RakeStep
        description 'maintenance_tasks.upgrade.remove_master_variant.description'

        runs_rake_task 'spree:remove_master_variant'
      end
    end
  end
end
