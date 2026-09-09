module Spree
  module MaintenanceTasks
    module Upgrade
      # Scopes custom field definitions to a store and fills the filter key
      # that used to be computed on read.
      class CustomFieldDefinitionStores < RakeStep
        description 'maintenance_tasks.upgrade.custom_field_definition_stores.description'

        runs_rake_task 'spree:upgrade:backfill_custom_field_definition_stores'
      end
    end
  end
end
