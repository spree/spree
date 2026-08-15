module Spree
  module MaintenanceTasks
    module Upgrade
      # Converts the shipping-scoped zones a delivery method references into
      # delivery zones, one per profile that referenced them.
      #
      # Set-based: the work is SQL over whole tables rather than a row walk, so
      # the run records what it did rather than progress through it.
      class ZonesToDeliveryZones < RakeStep
        description 'maintenance_tasks.upgrade.zones_to_delivery_zones.description'

        runs_rake_task 'spree:migrate_zones_to_delivery_zones'
      end
    end
  end
end
