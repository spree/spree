module Spree
  module MaintenanceTasks
    module Upgrade
      # Converts zone-scoped tax rates into country and state coded rates, splitting
      # multi-jurisdiction zones, and retypes zone price rules onto markets.
      #
      # Set-based: the work is SQL over whole tables rather than a row walk, so
      # the run records what it did rather than progress through it.
      class TaxZones < RakeStep
        description 'maintenance_tasks.upgrade.tax_zones.description'

        runs_rake_task 'spree:migrate_tax_zones'
      end
    end
  end
end
