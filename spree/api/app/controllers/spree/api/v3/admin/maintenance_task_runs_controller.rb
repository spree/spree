module Spree
  module Api
    module V3
      module Admin
        # Firing a maintenance task and steering the run it creates
        # (docs/plans/6.0-maintenance-tasks.md).
        #
        # No destroy: a run is the audit record of work that touched merchant
        # data, so it is never removed through the API. Stopping one is a
        # cancellation (MaintenanceTaskRuns::CancellationsController).
        class MaintenanceTaskRunsController < ResourceController
          include ActiveStorage::SetCurrent

          include MaintenanceTasksSwitch

          scoped_resource :maintenance_tasks

          request_params :maintenance_task_run do |body|
            body.attribute :task_name, :string,
              required: true, on: :create,
              example: 'capture_methods',
              description: 'The task to run, as `task_name` from `GET /upgrade_steps`.'
            body.attribute :arguments, :hash,
              description: "Values for the task's declared parameters, keyed by parameter name. " \
                           'A key the task does not declare is rejected.'
            body.attribute :dry_run, :boolean,
              description: 'Report what would change without writing. Ignored by tasks that do not support a dry run, which run for real.'
          end

          # POST /api/v3/admin/maintenance_task_runs
          def create
            authorize! :create, Spree::MaintenanceTaskRun

            # Not normalized: a task argument holding a prefixed id is the
            # task's to resolve, and decoding it here would hand it a raw key.
            body = params.permit(*declared_permitted_attributes)

            result = Spree::MaintenanceTasks::Start.call(
              api_type: body[:task_name].to_s,
              arguments: body[:arguments]&.to_h || {},
              dry_run: ActiveModel::Type::Boolean.new.cast(body[:dry_run]) || false,
              admin_user: try_spree_current_user,
              api_key: current_api_key,
              initiated_via: initiated_via
            )

            if result.success?
              render json: serialize_resource(result.value), status: :created
            else
              render_validation_error(result.error)
            end
          end

          protected

          def model_class
            Spree::MaintenanceTaskRun
          end

          def serializer_class
            Spree.api.admin_maintenance_task_run_serializer
          end

          # Runs are installation-wide: an upgrade step converts every store's
          # data, so a run belongs to no store.
          def scope
            model_class.all
          end

          def collection_includes
            [{ admin_user: [{ spree_roles: :resource }, { avatar_attachment: :blob }] }]
          end

          # A backtrace names internal paths and class names, so it rides with
          # the permission to act on runs rather than the one to read them.
          def serializer_params
            super.merge(show_backtrace: holds_permission?('write_maintenance_tasks'))
          end

          private

          # A secret key belongs to an integration rather than a person, so the
          # two are recorded distinctly — "who ran this" has a different answer
          # for each.
          def initiated_via
            try_spree_current_user ? 'dashboard' : 'api'
          end
        end
      end
    end
  end
end
