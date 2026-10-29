module Spree
  module MaintenanceTasks
    # Creates a run for a registered task and hands it to the runner
    # (docs/plans/6.0-maintenance-tasks.md).
    #
    # Everything that can be known before any work happens is checked here —
    # the task exists, its parameters validate, and no run of the same task
    # is already in flight — so an operator sees a 422
    # rather than a run that dies on its first record.
    class Start
      prepend ::Spree::ServiceModule::Base

      # @param task_name [String] a registered Spree::MaintenanceTask subclass name
      # @param api_type [String] the task's short name, in place of `task_name`
      #   — how an API caller names it, so a class name never has to cross
      #   the API
      # @param arguments [Hash] task parameters
      # @param dry_run [Boolean] preview mode; only honored by tasks that declare
      #   `supports_dry_run`
      # @param initiated_via [String] dashboard / api / cli
      # @param inline [Boolean] run synchronously (seeds, the CLI, the upgrade walk)
      # @return [Spree::ServiceModule::Base::Result] the run
      def call(task_name: nil, api_type: nil, arguments: {}, dry_run: false, admin_user: nil,
               api_key: nil, initiated_via: 'api', inline: false)
        task_class = if api_type.nil?
                       Spree::MaintenanceTask.find_registered(task_name)
                     else
                       Spree::MaintenanceTask.find_by_api_type(api_type)
                     end
        return failure(nil, unknown_task_error(api_type || task_name)) if task_class.nil?

        task_name = task_class.name

        arguments = (arguments || {}).stringify_keys
        unknown = arguments.keys - task_class.attribute_names
        return failure(nil, unknown_arguments_error(unknown)) if unknown.any?

        if initiated_via.to_s.in?(%w[api dashboard]) && superseded_step?(task_class, arguments)
          return failure(nil, superseded_error(task_class))
        end

        task = task_class.new(arguments)
        return failure(task, task.errors) unless task.valid?

        active = active_run_for(task_name)
        return failure(active, already_running_error(task_class)) if active

        run = build_run(task_class, arguments, dry_run, admin_user, api_key, initiated_via)
        return failure(run, run.errors) unless run.save

        dispatch(run, inline)

        success(run)
      end

      private

      def build_run(task_class, arguments, dry_run, admin_user, api_key, initiated_via)
        Spree::MaintenanceTaskRun.new(
          task_name: task_class.name,
          status: Spree::MaintenanceTaskRun.default_status,
          arguments: arguments,
          # A task that does not declare dry-run support would ignore the flag
          # and write for real; recording it as a preview would be a lie.
          dry_run: dry_run && task_class.dry_run_supported,
          admin_user: admin_user,
          api_key: api_key,
          initiated_via: initiated_via.to_s
        )
      end

      # The enqueue waits for the transaction so the worker cannot pick the
      # job up before the row it names is visible.
      def dispatch(run, inline)
        if inline
          ActiveRecord.after_all_transactions_commit { Spree::MaintenanceTasks::RunJob.perform_now(run.id, inline: true) }
        else
          Spree::MaintenanceTasks::RunJob.perform_later(run.id)
        end
      end

      # Upgrade steps of a release this installation already completed. The
      # dashboard never offers them; the command line still runs them, since
      # that is where an operator deliberately repeats a step.
      #
      # Refused even when the completed release was assumed rather than
      # recorded. The assumption is right for nearly every store, and for
      # those a repeated conversion damages data; a store that really skipped
      # a release is told to run its steps from the command line.
      def superseded_step?(task_class, arguments)
        Spree::Upgrade.superseded_steps.any? do |step|
          step['task_class'] == task_class.name ||
            (task_class <= Spree::MaintenanceTasks::UpgradeStep && step['id'] == arguments['step_id'])
        end
      end

      # One run per task at a time. Checked rather than locked: two requests
      # can both pass this check, and the runner then cancels the newer run
      # before it does any work (RunJob#duplicate_run?).
      def active_run_for(task_name)
        Spree::MaintenanceTaskRun.active.find_by(task_name: task_name)
      end

      def unknown_task_error(task_name)
        errors_for(:task_name, "#{task_name} is not a registered maintenance task")
      end

      def unknown_arguments_error(names)
        errors_for(:arguments, "the task takes no parameter named #{names.to_sentence}")
      end

      def superseded_error(task_class)
        errors_for(:base, "#{task_class.api_type} belongs to a release this store has already completed")
      end

      def already_running_error(task_class)
        errors_for(:base, "#{task_class.api_type} is already running")
      end

      def errors_for(attribute, message)
        ActiveModel::Errors.new(Spree::MaintenanceTaskRun.new).tap do |errors|
          errors.add(attribute, message)
        end
      end
    end
  end
end
