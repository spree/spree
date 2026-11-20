module SpreeAdyen
  class Gateway < ::Spree::Gateway
    # Adyen's standard webhooks, verified with the HMAC key configuration
    # stored. Parsing names what a delivery settles; it never acts on it.
    module Webhooks
      extend ActiveSupport::Concern

      MODIFICATION_EVENTS = {
        'CAPTURE' => %i[capture_succeeded capture_failed],
        'CANCELLATION' => %i[void_succeeded void_failed],
        'REFUND' => %i[refund_succeeded refund_failed]
      }.freeze
      # Failures Adyen reports as their own events, sometimes days after success.
      FAILURE_EVENTS = {
        'CAPTURE_FAILED' => :capture_failed,
        'REFUND_FAILED' => :refund_failed,
        'REFUNDED_REVERSED' => :refund_failed
      }.freeze
      CAPTURE_OUTCOMES = %i[capture_succeeded capture_failed].freeze
      VOID_OUTCOMES = %i[void_succeeded void_failed].freeze

      # @param raw_body [String]
      # @param headers [Hash]
      # @return [Hash, nil] the outcome, or nil for a delivery not acted on
      # @raise [Spree::PaymentMethod::WebhookSignatureError] for a body that is
      #   malformed, carries other than one item, fails the HMAC check, or
      #   names another merchant account or environment
      def parse_webhook_event(raw_body, _headers)
        body = JSON.parse(raw_body)
        raise Spree::PaymentMethod::WebhookSignatureError unless body.is_a?(Hash)

        item = notification_item!(body)
        verify_webhook!(body, item)

        event_code = item['eventCode'].to_s
        success = item['success'].to_s == 'true'

        if event_code == 'AUTHORISATION'
          authorisation_outcome(item) if success
        elsif MODIFICATION_EVENTS.key?(event_code)
          modification_outcome(MODIFICATION_EVENTS[event_code][success ? 0 : 1], item)
        elsif FAILURE_EVENTS.key?(event_code)
          modification_outcome(FAILURE_EVENTS[event_code], item)
        end
      rescue JSON::ParserError
        raise Spree::PaymentMethod::WebhookSignatureError
      end

      # A cancel names the payment by its PSP reference, which lives in
      # metadata: only payments waiting on Adyen are read, and compared in
      # Ruby. Captures and refunds are found by core's default.
      def modification_record(action, reference)
        return super unless VOID_OUTCOMES.include?(action.to_sym)

        payment_with_psp_reference(payments.requested, reference)
      end

      private

      def notification_item!(body)
        items = body['notificationItems']
        raise Spree::PaymentMethod::WebhookSignatureError unless items.is_a?(Array) && items.size == 1 && items.first.is_a?(Hash)

        item = items.first['NotificationRequestItem']
        raise Spree::PaymentMethod::WebhookSignatureError unless item.is_a?(Hash)

        item
      end

      # No development or test bypass: a delivery that does not verify is never
      # acted on.
      def verify_webhook!(body, item)
        validator = Adyen::Utils::HmacValidator.new
        keys = [preferred_hmac_key, preferred_previous_hmac_key].compact_blank
        verified = keys.any? { |key| validator.valid_webhook_hmac?(item, key) }
        raise Spree::PaymentMethod::WebhookSignatureError unless verified
        raise Spree::PaymentMethod::WebhookSignatureError unless item['merchantAccountCode'] == preferred_merchant_account
        raise Spree::PaymentMethod::WebhookSignatureError unless body['live'].to_s == (preferred_test_mode ? 'false' : 'true')
      end

      # An authorisation for one of this method's sessions, checked the way a
      # synchronous completion is; one that fails the check is not acted on.
      def authorisation_outcome(item)
        session_id = item.dig('additionalData', 'checkoutSessionId').presence
        return if session_id.nil?

        payment_session = payment_session_class.find_by(payment_method_id: id, external_id: session_id)
        return if payment_session.nil?

        result = SpreeAdyen::Result.from_notification(item)
        return if settlement_problem(payment_session, result)

        action = captured?(payment_session, result) ? :captured : :authorized
        { action: action, payment_session: payment_session, metadata: result.to_h }
      end

      # Names the record by reference only: core's job looks it up, and waits
      # for it when the outcome arrives before Spree has written it.
      def modification_outcome(action, item)
        reference = modification_reference(action, item)
        return if reference.blank?

        metadata = { 'reason' => item['reason'].presence }.compact
        return { action: action, reference: reference, metadata: metadata } unless CAPTURE_OUTCOMES.include?(action)

        amount = item['amount'].is_a?(Hash) ? item['amount'] : {}
        if amount['value'] && amount['currency']
          metadata['amount'] = SpreeAdyen::Amounts.from_adyen(amount['value'], amount['currency']).to_d.to_s('F')
        end
        { action: action, reference: reference, payment: payment_awaiting_capture(item['originalReference'].to_s), metadata: metadata }
      end

      # A capture or refund names itself by the PSP reference Adyen returned
      # for Spree's request; a late failure of an automatic capture names the
      # payment, written at settlement as its capture event's reference. A
      # cancel names the payment it released.
      def modification_reference(action, item)
        psp = item['pspReference'].to_s
        original = item['originalReference'].to_s
        return original if VOID_OUTCOMES.include?(action)
        return psp unless CAPTURE_OUTCOMES.include?(action) && original.present?

        events = Spree::PaymentCaptureEvent.where(payment_id: payments.select(:id))
        automatic_capture = !events.exists?(transaction_id: psp) && events.exists?(transaction_id: original)
        automatic_capture ? original : psp
      end

      # Bounded to payments mid-capture, or left processing by a capture whose
      # answer never came, and compared in Ruby: no JSON queries.
      def payment_awaiting_capture(original)
        payment_with_psp_reference(payments.processing, original)
      end

      def payment_with_psp_reference(scope, psp_reference)
        return if psp_reference.blank?

        id, = scope.pluck(:id, :metadata).find { |_id, metadata| metadata&.dig('adyen_psp_reference') == psp_reference }
        payments.find(id) if id
      end
    end
  end
end
