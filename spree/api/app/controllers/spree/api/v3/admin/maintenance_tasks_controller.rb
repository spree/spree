module Spree
  module Api
    module V3
      module Admin
        # Discovery for the registered maintenance tasks — what an operator can
        # run, what parameters each takes, and how its last run went
        # (docs/plans/6.0-maintenance-tasks.md).
        #
        # Tasks are classes rather than records, so this controller does not
        # inherit the resource CRUD: there is nothing to create or destroy, and
        # a task is addressed by its class name rather than an id.
        class MaintenanceTasksController < BaseController
          scoped_resource :maintenance_tasks

          # GET /api/v3/admin/maintenance_tasks
          def index
            authorize! :read, :maintenance_task

            render json: { data: Spree::MaintenanceTask.registered_classes.map { |task_class| present(task_class) } }
          end

          # GET /api/v3/admin/maintenance_tasks/:id
          # The id is the task's class name — Ruby constants are already the
          # stable identifier here, and minting a second one would only add a
          # lookup table to keep in sync.
          def show
            authorize! :read, :maintenance_task

            task_class = Spree::MaintenanceTask.find_registered(params[:id])
            raise ActiveRecord::RecordNotFound if task_class.nil?

            render json: { data: present(task_class) }
          end

          private

          def present(task_class)
            {
              name: task_class.name,
              description: task_class.resolved_description,
              parameters: task_class.parameters_schema,
              supports_dry_run: task_class.dry_run_supported,
              no_collection: task_class.collection_kind == :none,
              active_run: serialize_run(latest_runs[task_class.name]&.then { |run| run if run.active? }),
              last_run: serialize_run(latest_runs[task_class.name])
            }
          end

          # Runs embedded here follow the same backtrace rule as the runs
          # endpoint: visible to callers who may act on a run, not to those
          # who may only read one.
          def serializer_params
            { show_backtrace: can?(:update, Spree::MaintenanceTaskRun) }
          end

          # One query for the whole index rather than two per task.
          def latest_runs
            @latest_runs ||= Spree::MaintenanceTaskRun.
                             where(id: Spree::MaintenanceTaskRun.group(:task_name).select('MAX(id)')).
                             index_by(&:task_name)
          end

          def serialize_run(run)
            return nil if run.nil?

            Spree.api.admin_maintenance_task_run_serializer.new(run, params: serializer_params).to_h
          end
        end
      end
    end
  end
end
