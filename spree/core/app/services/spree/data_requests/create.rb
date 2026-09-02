module Spree
  module DataRequests
    # Opens a data subject request and queues the work.
    #
    # An in-flight request is returned rather than duplicated. That is the
    # rate limit: building an export is an unbounded read across a person's
    # whole history, and a customer holding the button down should not be able
    # to queue a hundred of them. It is also the honest answer — the request
    # they already made is still being worked on.
    class Create
      prepend Spree::ServiceModule::Base

      # @param store [Spree::Store]
      # @param customer [Spree::Customer]
      # @param kind [String] Spree::DataRequest::ACCESS or ERASURE
      # @param requested_by [Object, nil] the staff actor; nil when the
      #   subject asked for it themselves
      # @return [Spree::ServiceModule::Result]
      def call(store:, customer:, kind:, requested_by: nil)
        existing = in_flight_request(store: store, customer: customer, kind: kind)
        return success(existing) if existing

        data_request = Spree::DataRequest.new(
          store: store,
          customer: customer,
          kind: kind.to_s,
          email: customer.email,
          requested_by: requested_by
        )

        return failure(data_request) unless data_request.save

        Spree::DataRequests::ProcessJob.perform_later(data_request.prefixed_id)

        success(data_request)
      end

      private

      def in_flight_request(store:, customer:, kind:)
        Spree::DataRequest.where(store_id: store.id, customer_id: customer.id, kind: kind.to_s).
          in_progress.recent_first.first
      end
    end
  end
end
