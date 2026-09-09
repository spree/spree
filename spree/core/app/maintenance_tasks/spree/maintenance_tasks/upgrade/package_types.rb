module Spree
  module MaintenanceTasks
    module Upgrade
      # Gives every store the default set of boxes, cartons, pallets and
      # containers that package dimensions are chosen from.
      class PackageTypes < RakeStep
        description 'maintenance_tasks.upgrade.package_types.description'

        runs_rake_task 'spree:upgrade:package_types'
      end
    end
  end
end
