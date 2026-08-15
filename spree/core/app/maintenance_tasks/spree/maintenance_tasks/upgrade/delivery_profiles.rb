module Spree
  module MaintenanceTasks
    module Upgrade
      # Converts shipping categories into delivery profiles, folding away the ones
      # that never narrowed the method set.
      #
      # Set-based: the work is SQL over whole tables rather than a row walk, so
      # the run records what it did rather than progress through it.
      class DeliveryProfiles < RakeStep
        description 'maintenance_tasks.upgrade.delivery_profiles.description'

        runs_rake_task 'spree:migrate_delivery_profiles'
      end
    end
  end
end
