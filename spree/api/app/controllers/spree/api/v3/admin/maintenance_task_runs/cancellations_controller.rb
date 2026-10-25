module Spree
  module Api
    module V3
      module Admin
        module MaintenanceTaskRuns
          # POST /api/v3/admin/maintenance_task_runs/:maintenance_task_run_id/cancellation
          #
          # Stops a run for good. Work already committed stays committed; the
          # runner records the outcome (docs/plans/6.0-maintenance-tasks.md).
          class CancellationsController < Admin::BaseController
            scoped_resource :maintenance_tasks

            def create
              run = Spree::MaintenanceTaskRun.find_by_prefix_id!(params[:maintenance_task_run_id])
              authorize! :update, run

              result = Spree::MaintenanceTasks::Cancel.call(run: run)

              if result.success?
                render json: serialize_resource(result.value)
              else
                render_validation_error(result.error)
              end
            end

            protected

            def serializer_class
              Spree.api.admin_maintenance_task_run_serializer
            end

            def serializer_params
              super.merge(show_backtrace: true)
            end
          end
        end
      end
    end
  end
end
