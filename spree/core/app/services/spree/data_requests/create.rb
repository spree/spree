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
      # @param process [Boolean] whether to queue the work. False where the
      #   caller fulfils the request itself — the admin export renders the file
      #   inline for a waiting staffer, and queueing would additionally email
      #   the customer a copy of something they did not ask for
      # @return [Spree::ServiceModule::Result]
      def call(store:, customer:, kind:, requested_by: nil, process: true)
        # Nothing useful is left to answer with: an export would return the
        # tombstone and email a link to an address that no longer receives,
        # and a second erasure has nothing to erase.
        if customer.anonymized?
          data_request = Spree::DataRequest.new(customer: customer)
          data_request.errors.add(:base, Spree.t('data_request_errors.already_anonymized'))
          return failure(data_request)
        end

        data_request = nil
        existing = nil

        # Serialized on the customer row. A check-then-create leaves a window
        # where two callers both see nothing in flight and both queue an export
        # of the same person's whole history; taking the lock closes it without
        # a partial unique index, which MySQL does not support.
        customer.with_lock do
          existing = in_flight_request(store: store, customer: customer, kind: kind)

          unless existing
            data_request = Spree::DataRequest.new(
              store: store,
              customer: customer,
              kind: kind.to_s,
              email: customer.email,
              requested_by: requested_by
            )
            data_request.save
          end
        end

        return success(existing) if existing
        return failure(data_request) unless data_request.persisted?

        # Enqueued after the lock is released: the job may start immediately,
        # and it should not contend for the row this flow still holds.
        Spree::DataRequests::ProcessJob.perform_later(data_request.prefixed_id) if process

        success(data_request)
      end

      private

      # Only the person's own requests. A staff member exporting from the admin
      # opens their own row and answers it inline, and handing that back here
      # would close the customer's request with a file they can never download.
      def in_flight_request(store:, customer:, kind:)
        Spree::DataRequest.where(store_id: store.id, customer_id: customer.id, kind: kind.to_s,
                                 requested_by_id: nil).
          in_progress.recent_first.first
      end
    end
  end
end
