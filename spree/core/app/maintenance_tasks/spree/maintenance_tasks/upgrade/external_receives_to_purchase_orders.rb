module Spree
  module MaintenanceTasks
    module Upgrade
      # Turns 5.x supplier receives — stock transfers recorded without a source
      # location — into received purchase orders, and gives every remaining
      # transfer a store.
      class ExternalReceivesToPurchaseOrders < RakeStep
        description 'maintenance_tasks.upgrade.external_receives_to_purchase_orders.description'

        runs_rake_task 'spree:upgrade:migrate_external_receives_to_purchase_orders'
      end
    end
  end
end
