module Spree
  module Api
    module V3
      module Admin
        # Firing a maintenance task and steering the run it creates
        # (docs/plans/6.0-maintenance-tasks.md).
        #
        # No destroy: a run is the audit record of work that touched merchant
        # data, so it is never removed through the API. Stopping one is
        # `cancel`.
        class MaintenanceTaskRunsController < ResourceController
          include ActiveStorage::SetCurrent

          scoped_resource :maintenance_tasks

          # POST /api/v3/admin/maintenance_task_runs
          def create
            authorize! :create, Spree::MaintenanceTaskRun

            result = Spree::MaintenanceTasks::Start.call(
              task_name: params[:task_name],
              arguments: params[:arguments]&.to_unsafe_h || {},
              dry_run: ActiveModel::Type::Boolean.new.cast(params[:dry_run]) || false,
              store: current_store,
              admin_user: try_spree_current_user,
              api_key: current_api_key,
              initiated_via: initiated_via,
              csv_file: params[:csv_file].presence
            )

            if result.success?
              render json: serialize_resource(result.value), status: :created
            else
              render_validation_error(result.error)
            end
          end

          # PATCH /api/v3/admin/maintenance_task_runs/:id/pause
          def pause
            run_control(Spree::MaintenanceTasks::Pause)
          end

          # PATCH /api/v3/admin/maintenance_task_runs/:id/resume
          def resume
            run_control(Spree::MaintenanceTasks::Resume)
          end

          # PATCH /api/v3/admin/maintenance_task_runs/:id/cancel
          def cancel
            run_control(Spree::MaintenanceTasks::Cancel)
          end

          protected

          def model_class
            Spree::MaintenanceTaskRun
          end

          def serializer_class
            Spree.api.admin_maintenance_task_run_serializer
          end

          # Runs are installation-wide: a backfill walks every store's data, so
          # scoping the history to the header store would hide work that
          # touched it. The store on the row records where the operator was,
          # and is filterable like any other attribute.
          def scope
            model_class.all
          end

          def collection_includes
            [:admin_user, :store]
          end

          # A backtrace names internal paths and class names, so it rides with
          # the permission to act on runs rather than the one to read them.
          def serializer_params
            super.merge(show_backtrace: can?(:update, Spree::MaintenanceTaskRun))
          end

          private

          def run_control(service)
            @resource = find_resource
            authorize_resource!(@resource, :update)

            result = service.call(run: @resource)

            if result.success?
              render json: serialize_resource(result.value)
            else
              render_validation_error(result.error)
            end
          end

          # An invalid signed id is the caller's mistake, not a server fault —
          # the same 422 the imports upload path returns.
          rescue_from ActiveSupport::MessageVerifier::InvalidSignature do
            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
              message: 'Invalid csv_file signed id',
              status: :unprocessable_content
            )
          end

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
