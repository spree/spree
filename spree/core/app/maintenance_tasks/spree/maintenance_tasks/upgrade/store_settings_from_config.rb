module Spree
  module MaintenanceTasks
    module Upgrade
      # Copies the commerce settings that moved off the global config onto each
      # store, marking stores it has visited so a re-run cannot overwrite intent.
      #
      # Set-based: the work is SQL over whole tables rather than a row walk, so
      # the run records what it did rather than progress through it.
      class StoreSettingsFromConfig < RakeStep
        description 'maintenance_tasks.upgrade.store_settings_from_config.description'

        runs_rake_task 'spree:store_settings:backfill_from_config'
      end
    end
  end
end
