module Spree
  module MaintenanceTasks
    module Upgrade
      # Copies the coupon code a placed order was bought with onto the order
      # itself.
      class OrderCouponCodes < RakeStep
        description 'maintenance_tasks.upgrade.order_coupon_codes.description'

        runs_rake_task 'spree:backfill_order_coupon_codes'

        attribute :batch_size, :integer, default: 500

        passes_to_environment :batch_size, as: 'BATCH_SIZE'
      end
    end
  end
end
