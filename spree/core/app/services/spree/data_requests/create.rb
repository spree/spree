module Spree
  module DataRequests
    # Opens a data subject request and queues the work.
    #
    # An in-flight request is returned rather than duplicated. That is the
    # rate limit: building an export is an unbounded read across a person's
    # whole history, and a customer holding the button down should not be able
    # to queue a hundred of them. It is also the honest answer — the request
    # they already made is still being worked on.
    #
    # A request the customer raised themselves waits for confirmation from its
    # email address instead of being queued, because it reaches guest orders
    # placed at that address. Asking again while it waits sends the email again.
    class Create
      prepend Spree::ServiceModule::Base

      CONFIRMATION_EVENT = 'data_request.confirmation_requested'.freeze

      # @param store [Spree::Store]
      # @param customer [Spree::Customer]
      # @param kind [String] Spree::DataRequest::ACCESS or ERASURE
      # @param requested_by [Object, nil] the staff actor; nil when the
      #   subject asked for it themselves
      # @param process [Boolean] whether to queue the work. False where the
      #   caller fulfils the request itself — the admin export renders the file
      #   inline for a waiting staffer, and queueing would additionally email
      #   the customer a copy of something they did not ask for
      # @param confirm_by_email [Boolean] hold the request until it is
      #   confirmed from its email address; true for the customer's own requests
      # @param redirect_url [String, nil] the storefront page the confirmation
      #   link opens, already checked against the store's allowed origins
      # @return [Spree::ServiceModule::Result]
      def call(store:, customer:, kind:, requested_by: nil, process: true, confirm_by_email: false, redirect_url: nil)
        # Nothing useful is left to answer with: an export would return the
        # tombstone and email a link to an address that no longer receives,
        # and a second erasure has nothing to erase.
        if customer.anonymized?
          data_request = Spree::DataRequest.new(customer: customer)
          data_request.errors.add(:base, I18n.t('spree.data_request_errors.already_anonymized'))
          return failure(data_request)
        end

        data_request = nil
        existing = nil

        # Serialized on the customer row. A check-then-create leaves a window
        # where two callers both see nothing in flight and both queue an export
        # of the same person's whole history; taking the lock closes it without
        # a partial unique index, which MySQL does not support.
        customer.with_lock do
          lapse_unconfirmed_requests(store: store, customer: customer)
          existing = in_flight_request(store: store, customer: customer, kind: kind,
                                       include_unconfirmed: confirm_by_email)

          unless existing
            data_request = Spree::DataRequest.new(
              store: store,
              customer: customer,
              kind: kind.to_s,
              email: customer.email,
              requested_by: requested_by,
              status: confirm_by_email ? 'awaiting_confirmation' : 'pending'
            )
            data_request.save
          end
        end

        return failure(data_request) if data_request && !data_request.persisted?

        request = existing || data_request

        # Both happen after the lock is released: the job may start at once and
        # should not contend for the row this flow holds, and the email must
        # not go out before the row is committed.
        if request.awaiting_confirmation?
          request_confirmation(request, redirect_url: redirect_url)
        elsif data_request && process
          Spree::DataRequests::ProcessJob.perform_later(data_request.prefixed_id)
        end

        success(request)
      end

      private

      # Only the person's own requests. A staff member exporting from the admin
      # opens their own row and answers it inline, and handing that back here
      # would close the customer's request with a file they can never download.
      # A request still waiting for confirmation is returned only to the
      # customer: staff have checked who they are dealing with, so theirs
      # proceeds on its own row and the unconfirmed one lapses.
      def in_flight_request(store:, customer:, kind:, include_unconfirmed:)
        requests = Spree::DataRequest.where(store_id: store.id, customer_id: customer.id, kind: kind.to_s,
                                            requested_by_id: nil)
        open_requests = include_unconfirmed ? requests.in_progress.or(requests.confirmable) : requests.in_progress

        open_requests.recent_first.first
      end

      def lapse_unconfirmed_requests(store:, customer:)
        Spree::DataRequest.where(store_id: store.id, customer_id: customer.id).past_confirmation_window.
          find_each { |data_request| data_request.update!(status: 'lapsed') }
      end

      # The token travels in a credential event, which reaches only webhook
      # endpoints that name it and keeps the token out of the delivery log.
      def request_confirmation(data_request, redirect_url:)
        payload = data_request.event_payload_for(
          CONFIRMATION_EVENT,
          confirmation_token: data_request.generate_token_for(:confirmation),
          redirect_url: redirect_url.presence
        )
        data_request.publish_event(CONFIRMATION_EVENT, payload)
      end
    end
  end
end
