module Spree
  module MaintenanceTasks
    module Upgrade
      # Turns each store's checkout zone into the markets that now decide
      # where it sells.
      class CheckoutZonesToMarkets < RakeStep
        description 'maintenance_tasks.upgrade.checkout_zones_to_markets.description'

        runs_rake_task 'spree:markets:migrate_checkout_zones'
      end
    end
  end
end
