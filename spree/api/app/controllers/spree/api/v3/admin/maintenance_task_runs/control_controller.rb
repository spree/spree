module Spree
  module Api
    module V3
      module Admin
        module MaintenanceTaskRuns
          # Shared by the pause, resumption and cancellation of a run. Each is
          # a request the run's control service accepts or refuses; the runner
          # records the outcome (docs/plans/6.0-maintenance-tasks.md).
          class ControlController < Admin::BaseController
            scoped_resource :maintenance_tasks

            def create
              run = Spree::MaintenanceTaskRun.find_by_prefix_id!(params[:maintenance_task_run_id])
              authorize! :update, run

              result = service.call(run: run)

              if result.success?
                render json: serialize_resource(result.value)
              else
                render_validation_error(result.error)
              end
            end

            protected

            def service
              raise NotImplementedError
            end

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
