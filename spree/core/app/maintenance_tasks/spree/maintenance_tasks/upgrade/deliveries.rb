module Spree
  module MaintenanceTasks
    module Upgrade
      # Creates a delivery for every fulfillment that carries a 5.6 tracking
      # number, moving carrier tracking onto its own record.
      class Deliveries < RakeStep
        description 'maintenance_tasks.upgrade.deliveries.description'

        runs_rake_task 'spree:migrate_deliveries'

        attribute :batch_size, :integer, default: 1_000

        passes_to_environment :batch_size, as: 'BATCH_SIZE'
      end
    end
  end
end
