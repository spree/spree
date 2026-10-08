module Spree
  module MaintenanceTasks
    module Upgrade
      # Fills in the actor type on "who did this" rows written before those
      # columns became polymorphic. Such a row could only have pointed at an
      # admin user.
      class ActorTypes < RakeStep
        description 'maintenance_tasks.upgrade.actor_types.description'

        runs_rake_task 'spree:upgrade:backfill_actor_types'
      end
    end
  end
end
