module Spree
  module Api
    module V3
      module Admin
        module MaintenanceTaskRuns
          # POST /api/v3/admin/maintenance_task_runs/:maintenance_task_run_id/pause
          #
          # Asks a running run to stop at its next checkpoint, so it can be resumed later.
          class PausesController < ControlController
            protected

            def service
              Spree::MaintenanceTasks::Pause
            end
          end
        end
      end
    end
  end
end
