module Spree
  module MaintenanceTasks
    # Asks a running task to stop at its next checkpoint.
    #
    # The service writes the request (`pausing`) and the runner writes the
    # outcome (`paused`) — one writer per state, so a worker that dies between
    # the two never leaves a run claiming to be paused while its cursor is
    # still moving. A run that has not started yet pauses immediately: there is
    # no execution to wait for.
    class Pause
      prepend ::Spree::ServiceModule::Base

      # @param run [Spree::MaintenanceTaskRun]
      # @return [Spree::ServiceModule::Base::Result] the run
      def call(run:)
        return failure(run, not_pausable_error(run)) unless run.enqueued? || run.running?

        if run.enqueued?
          run.update(status: 'paused')
        else
          run.update(status: 'pausing')
        end

        return failure(run, run.errors) if run.errors.any?

        success(run.reload)
      end

      private

      def not_pausable_error(run)
        build_error("a run with status #{run.status} cannot be paused")
      end

      def build_error(message)
        ActiveModel::Errors.new(Spree::MaintenanceTaskRun.new).tap { |errors| errors.add(:base, message) }
      end
    end
  end
end
