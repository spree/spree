module Spree
  module Api
    module V3
      module Admin
        # The upgrade manifest as an ordered checklist, so the dashboard can
        # show what a release still needs and how far an operator has got
        # (docs/plans/6.0-maintenance-tasks.md).
        #
        # Read-only: running a step is starting the maintenance task it names,
        # which is what the runs endpoint already does. This exists to supply
        # the order and the operator notes, neither of which a task knows about
        # itself — a step's position in the manifest is a property of the
        # upgrade, not of the class.
        class UpgradeStepsController < BaseController
          scoped_resource :maintenance_tasks

          # GET /api/v3/admin/upgrade_steps
          #
          # Every step of every manifest this installation has reached, each
          # marked pending or superseded. Superseded steps are the releases it
          # has already been through: shown as history rather than hidden, but
          # never runnable, since re-running a completed conversion is how an
          # upgrade does damage.
          def index
            authorize! :read, :maintenance_task

            # A store installed fresh at this release has no upgrade to show —
            # not the outstanding steps, and not the history of releases it was
            # never on.
            return render json: { data: [], meta: meta } unless Spree::Upgrade.relevant?

            render json: {
              data: steps.map { |step| present(step) },
              meta: meta
            }
          end

          private

          def meta
            {
              completed_version: Spree::Upgrade.completed_boundary,
              # False when the boundary was assumed from the installed version
              # rather than recorded by a walk or a fresh install. The
              # dashboard says so, rather than presenting a guess as fact.
              completed_version_recorded: Spree::Upgrade.completed_boundary_known?,
              superseded_step_count: superseded_steps.size
            }
          end

          # Superseded first: they are the earlier releases, so listing them
          # above what is outstanding keeps the whole thing in release order.
          def steps
            @steps ||= superseded_steps + Spree::Upgrade.pending_steps
          end

          def superseded_steps
            @superseded_steps ||= Spree::Upgrade.superseded_steps
          end

          def superseded_ids
            @superseded_ids ||= superseded_steps.map { |step| step['id'] }.to_set
          end

          def present(step)
            task_name = Spree::Upgrade.task_class_name(step)
            run = latest_runs[run_key(step, task_name)]

            {
              # A boundary this installation has already crossed. The dashboard
              # shows these as done and refuses to run them.
              superseded: superseded_ids.include?(step['id']),
              id: step['id'],
              name: step['name'],
              notes: step['notes'],
              from: step['from'],
              to: step['to'],
              docs: step['docs'],
              task_name: Spree::MaintenanceTask.api_type_for(task_name),
              # A rake-backed step runs inside the shared runner, so the id it
              # was invoked with is what distinguishes one run from another.
              arguments: Spree::Upgrade.task_arguments(step),
              last_run: run && Spree.api.admin_maintenance_task_run_serializer.new(
                run, params: { show_backtrace: holds_permission?('write_maintenance_tasks') }
              ).to_h
            }
          end

          # The most recent run per step. Reduced in Ruby rather than grouped
          # in SQL: rake-backed runs are told apart by the step id inside their
          # `arguments` JSON, and grouping on a JSON column is not portable
          # across the adapters Spree supports. Only the three columns that
          # pick the latest run are read for the whole history; the runs kept
          # are then loaded in full.
          def latest_runs
            @latest_runs ||= begin
              latest_ids = Spree::MaintenanceTaskRun.where(task_name: manifest_task_names).order(:id).
                           pluck(:id, :task_name, :arguments).
                           each_with_object({}) do |(id, task_name, arguments), result|
                             result[[task_name, arguments&.dig('step_id')]] = id
                           end
              runs = Spree::MaintenanceTaskRun.includes(:admin_user).where(id: latest_ids.values).index_by(&:id)
              latest_ids.transform_values { |id| runs[id] }
            end
          end

          def manifest_task_names
            steps.map { |step| Spree::Upgrade.task_class_name(step) }.uniq
          end

          def run_key(step, task_name)
            [task_name, step['task_class'] ? nil : step['id']]
          end
        end
      end
    end
  end
end
