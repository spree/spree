module Spree
  module MaintenanceTasks
    module Upgrade
      # 5.6 → 6.0 conversion of the per-payment-method auto_capture boolean onto
      # the capture_method vocabulary (docs/plans/6.0-store-scoped-configuration.md).
      #
      # A method that captured on authorization charges at checkout. One that
      # did not only recorded "not at checkout" — the old column could not say
      # whether dispatch or staff was meant to take the money, and the store's
      # own setting is what decided. Leaving those rows empty is what makes them
      # keep inheriting it, so only the true case is written here, and the
      # collection is the true case alone: any other scope would never reach
      # zero remaining.
      class CaptureMethods < Spree::MaintenanceTask
        description 'maintenance_tasks.upgrade.capture_methods.description'
        supports_dry_run
        collection_batch_size 5_000

        def collection
          Spree::PaymentMethod.unscoped.where(capture_method: nil, auto_capture: true).order(:id)
        end

        def process(payment_method)
          return tally(:would_convert) if dry_run?

          payment_method.update_columns(capture_method: 'checkout', updated_at: Time.current)
          tally(:converted)
        end

        # Rows the conversion deliberately leaves alone, reported once so an
        # operator can see they were considered rather than missed.
        def after_complete
          return if dry_run?

          inheriting = Spree::PaymentMethod.unscoped.where(capture_method: nil, auto_capture: false).count
          tally(:left_inheriting_store_setting, inheriting) if inheriting.positive?
        end
      end
    end
  end
end
