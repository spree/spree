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
          def index
            authorize! :read, :maintenance_task

            render json: { data: Spree::Upgrade.pending_steps.map { |step| present(step) } }
          end

          private

          def present(step)
            task_name = step['task_class'] || Spree::MaintenanceTasks::UpgradeStep.name
            run = latest_runs[run_key(step, task_name)]

            {
              id: step['id'],
              name: step['name'],
              notes: step['notes'],
              from: step['from'],
              to: step['to'],
              docs: step['docs'],
              task_name: task_name,
              # A rake-backed step runs inside the generic wrapper, so the id it
              # was invoked with is what distinguishes one run from another.
              arguments: step['task_class'] ? {} : { step_id: step['id'] },
              last_run: run && Spree.api.admin_maintenance_task_run_serializer.new(
                run, params: { show_backtrace: can?(:update, Spree::MaintenanceTaskRun) }
              ).to_h
            }
          end

          # The most recent run per step. Loaded in one query and reduced in
          # Ruby rather than grouped in SQL: wrapper runs are told apart by the
          # step id inside their `arguments` JSON, and grouping on a JSON column
          # is not portable across the adapters Spree supports.
          def latest_runs
            @latest_runs ||= Spree::MaintenanceTaskRun.
                             where(task_name: manifest_task_names).
                             order(:id).
                             each_with_object({}) do |run, result|
              result[[run.task_name, run.arguments&.dig('step_id')]] = run
            end
          end

          def manifest_task_names
            Spree::Upgrade.pending_steps.
              map { |step| step['task_class'] || Spree::MaintenanceTasks::UpgradeStep.name }.uniq
          end

          def run_key(step, task_name)
            [task_name, step['task_class'] ? nil : step['id']]
          end
        end
      end
    end
  end
end
