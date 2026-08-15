module Spree
  module MaintenanceTasks
    # Creates a run for a registered task and hands it to the runner
    # (docs/plans/6.0-maintenance-tasks.md).
    #
    # Everything that can be known before any work happens is checked here —
    # the task exists, its parameters validate, its preconditions hold, and no
    # run of the same task is already in flight — so an operator sees a 422
    # rather than a run that dies on its first record.
    class Start
      prepend ::Spree::ServiceModule::Base

      # @param task_name [String] a registered Spree::MaintenanceTask subclass name
      # @param arguments [Hash] task parameters
      # @param dry_run [Boolean] preview mode; only honored by tasks that declare
      #   `supports_dry_run`
      # @param initiated_via [String] dashboard / api / cli / inline
      # @param inline [Boolean] run synchronously (seeds, the CLI, the upgrade walk)
      # @return [Spree::ServiceModule::Base::Result] the run
      def call(task_name:, arguments: {}, dry_run: false, store: nil, admin_user: nil,
               api_key: nil, initiated_via: 'api', parent_run: nil, inline: false,
               csv_file: nil)
        task_class = Spree::MaintenanceTask.find_registered(task_name)
        return failure(nil, unknown_task_error(task_name)) if task_class.nil?

        arguments = (arguments || {}).stringify_keys
        task = task_class.new(arguments)
        return failure(task, task.errors) unless task.valid?

        unmet = failing_precondition(task)
        return failure(task, precondition_error(unmet)) if unmet

        active = active_run_for(task_name)
        return failure(active, already_running_error(task_name)) if active

        return failure(task, missing_csv_error) if task_class.collection_kind == :csv && csv_file.blank?

        run = build_run(task_class, arguments, dry_run, store, admin_user, api_key,
                        initiated_via, parent_run)
        run.csv_file.attach(csv_file) if csv_file.present?
        return failure(run, run.errors) unless run.save

        dispatch(run, inline)

        success(run)
      end

      private

      def build_run(task_class, arguments, dry_run, store, admin_user, api_key,
                    initiated_via, parent_run)
        Spree::MaintenanceTaskRun.new(
          task_name: task_class.name,
          status: Spree::MaintenanceTaskRun.default_status,
          arguments: arguments,
          # A task that does not declare dry-run support would ignore the flag
          # and write for real; recording it as a preview would be a lie.
          dry_run: dry_run && task_class.dry_run_supported,
          store: store,
          admin_user: admin_user,
          api_key: api_key,
          initiated_via: initiated_via.to_s,
          parent_run: parent_run
        )
      end

      # The enqueue waits for the transaction so the worker cannot pick the
      # job up before the row it names is visible.
      def dispatch(run, inline)
        if inline
          ActiveRecord.after_all_transactions_commit { Spree::MaintenanceTasks::RunJob.perform_now(run.id) }
        else
          Spree::MaintenanceTasks::RunJob.perform_later(run.id)
        end
      end

      # One run per task at a time. Checked rather than locked: the loser of a
      # genuine race is refused by the runner when it loads the row, so the
      # cost of the gap is a logged no-op rather than two writers.
      def active_run_for(task_name)
        Spree::MaintenanceTaskRun.active.find_by(task_name: task_name)
      end

      def failing_precondition(task)
        task.class.preconditions.find do |precondition|
          block = precondition[:block]
          !(block.arity.zero? ? task.instance_exec(&block) : block.call(task))
        end
      end

      def unknown_task_error(task_name)
        errors_for(:task_name, "#{task_name} is not a registered maintenance task")
      end

      def missing_csv_error
        errors_for(:base, 'this task needs a CSV file')
      end

      def already_running_error(task_name)
        errors_for(:base, "#{task_name} is already running")
      end

      def precondition_error(precondition)
        errors_for(:base, precondition[:message])
      end

      def errors_for(attribute, message)
        ActiveModel::Errors.new(Spree::MaintenanceTaskRun.new).tap do |errors|
          errors.add(attribute, message)
        end
      end
    end
  end
end
