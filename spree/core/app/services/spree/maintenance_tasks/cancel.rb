module Spree
  module MaintenanceTasks
    # Stops a run for good. Like Pause, the service records the request and the
    # runner records the outcome; a run that has not started yet is cancelled
    # outright, since no execution will ever observe the request.
    #
    # Cancelling a run that is already `cancelling` also cancels it outright.
    # That is the way out when the worker that should have observed the first
    # request is gone: a run the runner never comes back to would otherwise
    # stay active and block every new run of its task.
    #
    # Cancelling is not a rollback — work already committed stays committed.
    # What a cancelled run keeps is its cursor, so an operator can see exactly
    # how far it got.
    class Cancel
      prepend ::Spree::ServiceModule::Base

      # @param run [Spree::MaintenanceTaskRun]
      # @return [Spree::ServiceModule::Base::Result] the run
      def call(run:)
        return failure(run, not_cancelable_error(run)) unless run.cancelable?

        # A pending pause means a worker is still mid-batch, so it, not this
        # service, records that the run stopped.
        if run.running? || run.pausing?
          run.update(status: 'cancelling')
        else
          run.update(status: 'cancelled', ended_at: Time.current)
        end

        return failure(run, run.errors) if run.errors.any?

        success(run.reload)
      end

      private

      def not_cancelable_error(run)
        build_error("a run with status #{run.status} cannot be cancelled")
      end

      def build_error(message)
        ActiveModel::Errors.new(Spree::MaintenanceTaskRun.new).tap { |errors| errors.add(:base, message) }
      end
    end
  end
end
