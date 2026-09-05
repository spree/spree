module Spree
  module DataRequests
    # Carries out a data subject request: builds and attaches the export for
    # an access request, runs the anonymizer for an erasure request.
    #
    # In the workflow tier for its hooks — a host app that must include data
    # Spree does not model (a loyalty ledger, a support-ticket history) adds
    # it to the payload here, and that is the only place where the shape of a
    # subject access response can be completed.
    #
    # Marking a request `failed` is the caller's job, not this flow's: see
    # {Spree::DataRequests::ProcessJob}. A workflow cannot rescue around its
    # own steps, because FailureSignal and Halted descend from Exception and
    # rescuing swallows the result the caller is waiting for.
    class Fulfill < Spree::Workflow
      hooks :before_fulfill, :extend_payload, :after_fulfill

      # Builds the payload for a request, hook included.
      #
      # Exposed as a class method because the admin export renders inline for a
      # staffer who is waiting, rather than going through the queued flow — and
      # an Art. 15 response assembled without the extension point would omit
      # exactly the host-app data the hook exists to attach. Both paths build
      # the same document.
      #
      # @param data_request [Spree::DataRequest]
      # @return [Hash]
      def self.payload_for(data_request)
        new.send(:export_payload, data_request)
      end


      # @param data_request [Spree::DataRequest]
      # @return [Spree::ServiceModule::Result] the fulfilled request
      def perform(data_request:)
        super

        step :ensure_pending
        step :mark_processing

        run_hooks :before_fulfill

        step :fulfill_request
        step :mark_completed

        run_hooks :after_fulfill

        success(data_request.reload)
      end

      private

      def ensure_pending
        return if data_request.pending?

        failure(data_request, Spree.t('data_request_errors.not_pending'))
      end

      def mark_processing
        data_request.update!(status: 'processing')
      end

      def fulfill_request
        data_request.access? ? build_export : erase_customer
      end

      def build_export
        customer = data_request.customer

        # An erasure can land while this sits in the queue. Answering now would
        # write a file into private storage for someone who asked to be
        # forgotten — redacted, and behind a token the erasure already cleared,
        # so nobody could open it, but a file about them all the same and a
        # request they can never collect. Refusing says what happened.
        #
        # Read and attach under the customer's row lock, which is the same lock
        # the erasure takes: checking without it leaves a window where the
        # anonymizer starts after the check and finishes its attachment scan
        # before this attaches, stranding a full personal-data file it will
        # never see.
        return attach_export unless customer

        refused = false

        customer.with_lock do
          if customer.reload.anonymized?
            refused = true
          else
            attach_export
          end
        end

        return unless refused

        failure(data_request, Spree.t('data_request_errors.already_anonymized'))
      end

      def attach_export
        payload = export_payload(data_request)

        data_request.export_file.attach(
          io: StringIO.new(JSON.pretty_generate(payload)),
          filename: "#{data_request.number.downcase}.json",
          content_type: 'application/json'
        )
        data_request.expires_at = Spree::DataRequest::DEFAULT_EXPIRY.from_now
      end

      # The document itself.
      #
      # Binds `data_request` through the workflow's own argument mechanism, so
      # a hook handler reads the same `workflow.data_request` it does in the
      # queued flow rather than a reader that happens to exist.
      #
      # @param request [Spree::DataRequest]
      # @return [Hash]
      def export_payload(request)
        @data_request = request
        self.class.define_argument_readers([:data_request])

        payload = Spree.customer_data_export_service.new(
          customer: request.customer,
          store: request.store
        ).call

        # The extension point for data Spree does not model. Handlers return a
        # hash, which run_hooks deep-merges — so a host app adds its own keys
        # without being able to silently drop Spree's.
        payload.deep_merge(run_hooks(:extend_payload).presence || {})
      end

      def erase_customer
        customer = data_request.customer

        # Already erased is the outcome this request asked for, however it came
        # about — staff may have run it while this job sat in the queue, or the
        # person may have asked twice. Recording that as a failure would leave
        # someone whose data IS gone holding a failed request, and a failed
        # request is what stops them opening another.
        return if customer.anonymized?

        result = Spree.customer_anonymize_workflow.call(
          customer: customer,
          store: data_request.store,
          requested_by: data_request.requested_by
        )

        return if result.success?

        # The erasure can also be refused because a concurrent one claimed the
        # account after the check above — the two are not distinguishable from
        # the refusal itself, so the state is what answers. Only a person who
        # is still identified represents a request this flow failed to serve.
        return if customer.reload.anonymized?

        failure(data_request, result.error.to_s)
      end

      def mark_completed
        data_request.update!(status: 'completed', completed_at: Time.current)
        data_request.publish_event('data_request.completed')
      end
    end
  end
end
