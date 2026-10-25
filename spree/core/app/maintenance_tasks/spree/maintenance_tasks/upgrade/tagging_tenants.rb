module Spree
  module MaintenanceTasks
    module Upgrade
      # Stamps the store on taggings written without one, so tags added in bulk
      # appear in the admin tag list.
      class TaggingTenants < RakeStep
        description 'maintenance_tasks.upgrade.tagging_tenants.description'

        runs_rake_task 'spree:upgrade:backfill_tagging_tenants'
      end
    end
  end
end
