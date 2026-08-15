module Spree
  module MaintenanceTasks
    module Upgrade
      # Moves return authorizations onto the 6.0 Return and Exchange models.
      #
      # Resumable by construction: the legacy number is copied onto the new
      # record and uniquely indexed there, so what is still outstanding is a
      # query rather than tracked state.
      class Returns < RakeStep
        description 'maintenance_tasks.upgrade.returns.description'

        runs_rake_task 'spree:upgrade:migrate_returns'

        attribute :skip_failed_rows, :boolean, default: false
        attribute :batch_size, :integer, default: 500

        passes_to_environment :skip_failed_rows, as: 'SKIP_FAILED_ROWS'
        passes_to_environment :batch_size, as: 'BATCH_SIZE'
      end
    end
  end
end
