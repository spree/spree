module Spree
  module DataRequests
    # Builds the export (or runs the erasure) for a data subject request off
    # the request cycle.
    #
    # Not retry-safe by design, the same reasoning as the CSV export job: each
    # run attaches a fresh blob and enqueues another email, so a transient
    # failure that retried would leave the subject with two copies of
    # everything a shop knows about them.
    #
    # A request that fails is recorded as `failed` with its message rather
    # than left in `processing`, because a request stuck mid-flight would
    # block the subject from asking again — the pending-request check is what
    # rate-limits them.
    class ProcessJob < Spree::BaseJob
      queue_as Spree.queues.default

      retry_on ActiveRecord::Deadlocked,
               ActiveRecord::LockWaitTimeout,
               ActiveRecord::ConnectionNotEstablished,
               ActiveRecord::ConnectionFailed,
               ActiveRecord::RecordNotFound,
               attempts: 1

      def perform(data_request_id)
        data_request = Spree::DataRequest.find_by_prefix_id!(data_request_id)
        result = Spree::DataRequests::Fulfill.call(data_request: data_request)

        record_failure(data_request, result.error.to_s) if result.failure?
      rescue StandardError => e
        record_failure(data_request, e.message) if data_request
        raise
      end

      private

      def record_failure(data_request, message)
        return if data_request.completed?

        data_request.update_columns(
          status: 'failed',
          error_message: message.to_s.first(1000).presence,
          updated_at: Time.current
        )
      end
    end
  end
end
