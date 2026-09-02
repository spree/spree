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
        payload = Spree.customer_data_export_service.new(
          customer: data_request.customer,
          store: data_request.store
        ).call

        # The extension point for data Spree does not model. Handlers return a
        # hash, which run_hooks deep-merges — so a host app adds its own keys
        # without being able to silently drop Spree's.
        payload = payload.deep_merge(run_hooks(:extend_payload).presence || {})

        data_request.export_file.attach(
          io: StringIO.new(JSON.pretty_generate(payload)),
          filename: "#{data_request.number.downcase}.json",
          content_type: 'application/json'
        )
        data_request.expires_at = Spree::DataRequest::DEFAULT_EXPIRY.from_now
      end

      def erase_customer
        result = Spree.customer_anonymize_workflow.call(
          customer: data_request.customer,
          store: data_request.store,
          requested_by: data_request.requested_by
        )

        return if result.success?

        failure(data_request, result.error.to_s)
      end

      def mark_completed
        data_request.update!(status: 'completed', completed_at: Time.current)
        data_request.publish_event('data_request.completed')
      end
    end
  end
end
