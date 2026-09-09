module Spree
  module DataRequests
    # Builds the export (or runs the erasure) for a data subject request off
    # the request cycle.
    #
    # A request that fails is recorded as `failed` with its message rather
    # than left in `processing`, because a request stuck mid-flight would
    # block the subject from asking again — the pending-request check is what
    # rate-limits them. That is why the work is wrapped rather than left to
    # raise: the base class's retries cover the transient database errors, and
    # anything else has to leave the request in a state the subject can act on.
    #
    # Its own queue: an export reads a person's whole history and a statutory
    # clock is running on it, so a shop with a long import backlog should be
    # able to give these their own workers.
    class ProcessJob < Spree::BaseJob
      queue_as Spree.queues.data_requests

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
