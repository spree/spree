module Spree
  module MaintenanceTasks
    module Upgrade
      # Converts the flat-rate calculator's order-total bounds into delivery method
      # rules, which is where eligibility lives in 6.0.
      #
      # Set-based: the work is SQL over whole tables rather than a row walk, so
      # the run records what it did rather than progress through it.
      class CalculatorBoundsToDeliveryMethodRules < RakeStep
        description 'maintenance_tasks.upgrade.calculator_bounds_to_delivery_method_rules.description'

        runs_rake_task 'spree:migrate_calculator_bounds_to_delivery_method_rules'
      end
    end
  end
end
