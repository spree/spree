module Spree
  module Api
    module V3
      module Admin
        module MaintenanceTaskRuns
          # POST /api/v3/admin/maintenance_task_runs/:maintenance_task_run_id/cancellation
          #
          # Stops a run for good. Work already committed stays committed.
          class CancellationsController < ControlController
            protected

            def service
              Spree::MaintenanceTasks::Cancel
            end
          end
        end
      end
    end
  end
end
