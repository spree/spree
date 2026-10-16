module Spree
  module Api
    module V3
      module Admin
        module MaintenanceTaskRuns
          # POST /api/v3/admin/maintenance_task_runs/:maintenance_task_run_id/resumption
          #
          # Restarts a paused or failed run from where it stopped.
          class ResumptionsController < ControlController
            protected

            def service
              Spree::MaintenanceTasks::Resume
            end
          end
        end
      end
    end
  end
end
