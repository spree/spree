module Spree
  module MaintenanceTasks
    module Upgrade
      # Sets whether each market's prices include tax from the convention its tax
      # rates had, now that rates no longer carry that flag.
      class MarketTaxInclusive < RakeStep
        description 'maintenance_tasks.upgrade.market_tax_inclusive.description'

        runs_rake_task 'spree:markets:backfill_tax_inclusive'
      end
    end
  end
end
