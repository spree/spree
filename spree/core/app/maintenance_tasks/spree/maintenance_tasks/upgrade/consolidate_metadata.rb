module Spree
  module MaintenanceTasks
    module Upgrade
      # Merges any leftover public and private metadata pair into the single
      # metadata column. A safety net for schemas changed out of band — the
      # migration performs the merge itself before dropping the old column.
      #
      # Set-based: the work is SQL over whole tables rather than a row walk, so
      # the run records what it did rather than progress through it.
      class ConsolidateMetadata < RakeStep
        description 'maintenance_tasks.upgrade.consolidate_metadata.description'

        runs_rake_task 'spree:upgrade:consolidate_metadata'
      end
    end
  end
end
