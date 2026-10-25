module Spree
  module MaintenanceTasks
    module Upgrade
      # Gives every store the default tax exemption reasons and links existing
      # exemption certificates to them.
      class TaxExemptionReasons < RakeStep
        description 'maintenance_tasks.upgrade.tax_exemption_reasons.description'

        runs_rake_task 'spree:upgrade:tax_exemption_reasons'
      end
    end
  end
end
