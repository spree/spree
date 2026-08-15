module Spree
  module MaintenanceTasks
    # Restarts a paused or failed run from its cursor.
    #
    # A fresh job is enqueued with no continuation of its own — the runner
    # seeds the step from the row, which is why the cursor lives there rather
    # than only in the job data. Resuming a failed run clears the recorded
    # error: the row describes the current attempt, and the previous failure
    # is already in the event log.
    class Resume
      prepend ::Spree::ServiceModule::Base

      # @param run [Spree::MaintenanceTaskRun]
      # @return [Spree::ServiceModule::Base::Result] the run
      def call(run:, inline: false)
        return failure(run, not_resumable_error(run)) unless run.resumable?
        return failure(run, unknown_task_error(run)) if run.task_class.nil?

        conflicting = Spree::MaintenanceTaskRun.active.where.not(id: run.id).find_by(task_name: run.task_name)
        return failure(conflicting, already_running_error(run.task_name)) if conflicting

        run.update!(
          status: 'enqueued',
          ended_at: nil,
          error_class: nil,
          error_message: nil,
          error_backtrace: nil
        )

        if inline
          ActiveRecord.after_all_transactions_commit { Spree::MaintenanceTasks::RunJob.perform_now(run.id) }
        else
          Spree::MaintenanceTasks::RunJob.perform_later(run.id)
        end

        success(run.reload)
      end

      private

      def not_resumable_error(run)
        build_error("a run with status #{run.status} cannot be resumed")
      end

      def unknown_task_error(run)
        build_error("#{run.task_name} is no longer a registered maintenance task")
      end

      def already_running_error(task_name)
        build_error("#{task_name} is already running")
      end

      def build_error(message)
        ActiveModel::Errors.new(Spree::MaintenanceTaskRun.new).tap { |errors| errors.add(:base, message) }
      end
    end
  end
end
