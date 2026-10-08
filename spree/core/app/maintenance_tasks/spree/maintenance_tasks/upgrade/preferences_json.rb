module Spree
  module MaintenanceTasks
    module Upgrade
      # Converts any preferences row the migration left in YAML to JSON, and
      # moves secrets still in plain preferences to the encrypted column.
      class PreferencesJson < RakeStep
        description 'maintenance_tasks.upgrade.preferences_json.description'

        runs_rake_task 'spree:upgrade:preferences_json'
      end
    end
  end
end
