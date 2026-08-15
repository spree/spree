module Spree
  module MaintenanceTasks
    module Upgrade
      # Renames the shipment vocabulary to fulfillment across the polymorphic
      # columns that name it, and converts delivery method visibility.
      #
      # Set-based: the work is SQL over whole tables rather than a row walk, so
      # the run records what it did rather than progress through it.
      class ShippingToDelivery < RakeStep
        description 'maintenance_tasks.upgrade.shipping_to_delivery.description'

        runs_rake_task 'spree:migrate_shipping_to_delivery'
      end
    end
  end
end
