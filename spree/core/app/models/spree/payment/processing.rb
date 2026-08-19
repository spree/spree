require_dependency 'spree/payment/gateway_options'

module Spree
  class Payment < Spree.base_class
    # Gateway mechanics shared by the payments workflows and the payment
    # methods: option serialization, response bookkeeping, error
    # translation and instrumentation. The flows themselves — capture,
    # void, authorize/purchase — live in app/workflows/spree/payments;
    # the deprecated verb methods below delegate there until 7.0.
    #
    # Those five carry a full major's window rather than the usual one
    # release: they have been the public way to move money since Spree 1,
    # every payment extension and host override calls them, and the
    # replacement is a different shape (a workflow result, not a boolean),
    # so migrating is real work rather than a rename.
    module Processing
      extend ActiveSupport::Concern
      include Spree::InstrumentsGatewayCalls

      included do
        class_attribute :gateway_options_class
        self.gateway_options_class = Spree::Payment::GatewayOptions
      end

      # @deprecated Call Spree.payment_process_workflow — removed in 7.0.
      def process!
        Spree::Deprecation.warn('Spree::Payment#process! is deprecated and will be removed in Spree 7.0. Call Spree.payment_process_workflow instead.')
        run_payment_workflow(Spree.payment_process_workflow, payment: self)
      end

      # @deprecated Call Spree.payment_process_workflow — removed in 7.0.
      def authorize!
        Spree::Deprecation.warn('Spree::Payment#authorize! is deprecated and will be removed in Spree 7.0. Call Spree.payment_process_workflow instead.')
        run_payment_workflow(Spree.payment_process_workflow, payment: self, action: :authorize)
      end

      # @deprecated Call Spree.payment_process_workflow — removed in 7.0.
      def purchase!
        Spree::Deprecation.warn('Spree::Payment#purchase! is deprecated and will be removed in Spree 7.0. Call Spree.payment_process_workflow instead.')
        run_payment_workflow(Spree.payment_process_workflow, payment: self, action: :purchase)
      end

      # @deprecated Call Spree.payment_capture_workflow — removed in 7.0.
      def capture!(amount = nil)
        Spree::Deprecation.warn('Spree::Payment#capture! is deprecated and will be removed in Spree 7.0. Call Spree.payment_capture_workflow instead.')
        run_payment_workflow(Spree.payment_capture_workflow, payment: self, amount: amount)
      end

      # @deprecated Call Spree.payment_void_workflow — removed in 7.0.
      def void_transaction!
        Spree::Deprecation.warn('Spree::Payment#void_transaction! is deprecated and will be removed in Spree 7.0. Call Spree.payment_void_workflow instead.')
        run_payment_workflow(Spree.payment_void_workflow, payment: self)
      end

      # Confirms a payment already authorized or captured on the gateway side
      # (SDK / Drop-in / payment session flows) — the local status move only,
      # no gateway call.
      #
      # Deliberately not a workflow, unlike its siblings: its only caller is
      # PaymentSession#settle_payment!, which runs inside owner.with_lock —
      # and a workflow cannot run there (external_step refuses a
      # workflow-opened transaction, halt! raises inside any transaction).
      # The lock is what makes settlement exactly-once when the webhook
      # races the customer's synchronous return, so it stays and this stays
      # pure database work. There is no gateway call to push behind an
      # external_step and no compensation to run, so nothing about it earns
      # the workflow tier.
      #
      # @param captured [Boolean, nil] whether the gateway reports the funds
      #   as captured. Callers who know the gateway state pass it; nil falls
      #   back to when the payment method charges.
      def confirm!(captured: nil)
        captured = payment_method&.capture_at_checkout? if captured.nil?

        started_processing! if checkout?

        if captured && can_complete?
          complete!
          capture_events.create!(amount: amount)
        elsif can_pend?
          pend!
        end
      end

      # Settles the payment for a canceled order: releases an uncaptured
      # authorization, refunds a captured one. The gateway decides which —
      # payment_method.cancel routes refunds through Refunds::Create.
      def cancel!
        response = instrument_gateway_call(:cancel, payment_method) do
          payment_method.cancel(response_code, self)
        end
        handle_response(response, :void)
      end

      def gateway_options
        owner.reload
        gateway_options_class.new(self).to_hash
      end

      # Records a gateway response on the payment: bookkeeping (response
      # code, AVS/CVV results) plus the status write. A failed response
      # writes `failed` non-raising — gateway_error below is the exception
      # this path reports, and a validation problem must not preempt it.
      def handle_response(response, success_state, _failure_state = :failure)
        if response.success?
          unless response.authorization.nil?
            self.response_code = response.authorization
            self.avs_response = response.avs_result['code']

            if response.cvv_result
              self.cvv_response_code = response.cvv_result['code']
              self.cvv_response_message = response.cvv_result['message']
            end
          end

          case success_state
          when :complete then complete!
          when :pend then pend!
          when :void then void!
          else raise ArgumentError, "Unknown payment success state: #{success_state.inspect}"
          end
        else
          self.status = 'failed'
          save
          gateway_error(response)
        end
      end

      def protect_from_connection_error
        yield
      rescue Spree::PaymentConnectionError => e
        failure!
        gateway_error(e)
      end

      def gateway_error(error)
        text = if error.is_a? Spree::PaymentResponse
                 error.params['message'] || error.params['response_reason_text'] || error.message
               elsif error.is_a? Spree::PaymentConnectionError
                 Spree.t(:unable_to_connect_to_gateway)
               else
                 error.to_s
               end
        Rails.logger.error(Spree.t(:gateway_error))
        Rails.logger.error("  #{error.to_yaml}")
        raise Core::GatewayError, text
      end

      def token_based?
        source.gateway_customer_profile_id.present? || source.gateway_payment_profile_id.present?
      end

      private

      # Preserves the retired verbs' contract: true on success, GatewayError
      # on failure.
      def run_payment_workflow(workflow, **arguments)
        result = workflow.call(**arguments)
        raise Spree::Core::GatewayError, result.error.value.to_s if result.failure?

        true
      end
    end
  end
end
