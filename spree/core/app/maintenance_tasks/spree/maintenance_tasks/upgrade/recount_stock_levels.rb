module Spree
  module MaintenanceTasks
    module Upgrade
      # Recomputes the reserved and incoming counters on every stock level from
      # their sources, so counters that start at zero on an existing install
      # reflect what is actually held and on its way.
      class RecountStockLevels < RakeStep
        description 'maintenance_tasks.upgrade.recount_stock_levels.description'

        runs_rake_task 'spree:stock:recount_levels'
      end
    end
  end
end
