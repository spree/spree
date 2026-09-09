module Spree
  module MaintenanceTasks
    module Upgrade
      # Rewrites Option Value promotion rules so they reference option values
      # directly rather than the join rows they used to point at.
      class PromotionOptionValueRules < RakeStep
        description 'maintenance_tasks.upgrade.promotion_option_value_rules.description'

        runs_rake_task 'spree:upgrade:migrate_promotion_option_value_rules'

        attribute :skip_failed_rows, :boolean, default: false

        passes_to_environment :skip_failed_rows, as: 'SKIP_FAILED_ROWS'
      end
    end
  end
end
