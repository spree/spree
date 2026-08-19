module Spree
  module MaintenanceTasks
    module Upgrade
      # Copies each legacy store credit category name into the memo of credits that
      # have none. A credit's reason is its originator plus the memo in 6.0.
      class StoreCreditCategories < RakeStep
        description 'maintenance_tasks.upgrade.store_credit_categories.description'

        runs_rake_task 'spree:upgrade:fold_store_credit_categories'
      end
    end
  end
end
