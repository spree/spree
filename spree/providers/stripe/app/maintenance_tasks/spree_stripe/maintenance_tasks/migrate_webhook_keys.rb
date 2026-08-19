module SpreeStripe
  module MaintenanceTasks
    # Moves Stripe webhook signing secrets onto the gateway that uses them.
    #
    # Ships with this gem rather than core, which is what makes the manifest
    # step optional: an installation without spree_stripe has neither the rake
    # task nor this class, and the upgrade walk skips the step rather than
    # failing on it.
    class MigrateWebhookKeys < Spree::MaintenanceTasks::Upgrade::RakeStep
      description 'maintenance_tasks.upgrade.stripe_webhook_keys.description'

      runs_rake_task 'spree:upgrade:migrate_stripe_webhook_keys'
    end
  end
end
