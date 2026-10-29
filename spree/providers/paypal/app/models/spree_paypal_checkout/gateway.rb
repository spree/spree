module SpreePaypalCheckout
  # PayPal Checkout gateway built on the payment session API. A session is a
  # PayPal order: the buyer approves it in PayPal's window, then the server
  # captures or authorizes it, so the server is the only thing that moves money.
  #
  # A payment's response code is always the PayPal order id, the key core uses
  # to link a session to its payment. The capture and authorization ids PayPal
  # issues are read from the order whenever a capture, refund or void needs them.
  class Gateway < ::Spree::Gateway
    self.accepts_money_amounts = true

    # A capture PayPal has taken, whether or not it was refunded since.
    CAPTURED_STATUSES = %w[COMPLETED PARTIALLY_REFUNDED REFUNDED].freeze
    # An authorization that can still be captured or voided.
    OPEN_AUTHORIZATION_STATUSES = %w[CREATED PARTIALLY_CAPTURED PENDING].freeze
    # Transport failures where PayPal may or may not have acted on the request.
    CONNECTION_ERRORS = [Faraday::TimeoutError, Faraday::ConnectionFailed].freeze

    # A refusal from PayPal, with its issue code (INSTRUMENT_DECLINED,
    # AUTHORIZATION_EXPIRED, …) kept apart from the message for callers that
    # act on it.
    class PaypalError < Spree::Core::GatewayError
      attr_reader :issue

      def initialize(message = nil, issue: nil)
        super(message)
        @issue = issue
      end
    end

    preference :client_id, :password
    preference :client_secret, :password
    # The credentials do not say which PayPal environment they belong to.
    preference :test_mode, :boolean, default: true
    # Written by webhook registration, never by an operator.
    preference :webhook_id, :string, internal: true

    validates :preferred_client_id, :preferred_client_secret, presence: true
    validate :validate_credentials, unless: -> { Rails.env.test? }, if: :credentials_changed?

    def self.logo_url
      'https://spreecommerce.org/docs/images/integrations/logos/paypal.png'
    end

    def self.docs_url
      'https://spreecommerce.org/docs/integrations/payments/paypal'
    end

    def provider_class
      self.class
    end

    def default_name
      'PayPal'
    end

    def method_type
      'spree_paypal_checkout'
    end

    def payment_icon_name
      'paypal'
    end

    def session_required?
      true
    end

    def payment_session_class
      Spree::PaymentSessions::PaypalCheckout
    end

    # No saved PayPal accounts in this release, so core never calls
    # create_profile and passes no source to credit and void.
    def payment_profiles_supported?
      false
    end

    def available_for_order?(order)
      super && SpreePaypalCheckout::Amounts.supported_currency?(order.currency)
    end

    # CAPTURE takes the money when the session completes; AUTHORIZE holds it
    # for Spree to capture on dispatch or by hand.
    #
    # @return [String]
    def paypal_intent
      if capture_at_checkout?
        PaypalServerSdk::CheckoutPaymentIntent::CAPTURE
      else
        PaypalServerSdk::CheckoutPaymentIntent::AUTHORIZE
      end
    end

    # PayPal's activity page lists transactions, not orders, so the link needs
    # the capture or authorization id recorded at settlement.
    def gateway_dashboard_payment_url(payment)
      transaction_id = payment.metadata['paypal_capture_id'].presence || payment.metadata['paypal_authorization_id'].presence
      return if transaction_id.blank?

      host = preferred_test_mode ? 'www.sandbox.paypal.com' : 'www.paypal.com'
      "https://#{host}/activity/payment/#{transaction_id}"
    end

    # Called by core when a session-created payment moves on. The session has
    # already captured or authorized the order, so this reads it back.
    #
    # @param _money [Spree::Money]
    # @param _payment_source [Spree::PaymentSource, nil]
    # @param gateway_options [Hash] Spree::Payment::GatewayOptions#to_hash
    # @return [Spree::PaymentResponse]
    def authorize(_money, _payment_source, gateway_options = {})
      read_back(gateway_options)
    end

    # @see #authorize
    def purchase(_money, _payment_source, gateway_options = {})
      read_back(gateway_options)
    end

    # Captures the order's authorization, in part or in full. It is the
    # payment's only capture (`final_capture`): core authorizes any remainder
    # as a payment of its own.
    #
    # @param money [Spree::Money]
    # @param order_id [String] the PayPal order id
    # @param gateway_options [Hash]
    # @return [Spree::PaymentResponse]
    # @raise [PaypalError] when PayPal refuses, or holds the capture as pending
    def capture(money, order_id, gateway_options = {})
      paypal_order = protect_from_error { paypal_order(order_id) }

      capture = captures(paypal_order).first
      if capture
        raise_pending_capture(capture) if capture['status'] == 'PENDING'
        return success(order_id, paypal_order) if capture['status'].in?(CAPTURED_STATUSES)
      end

      authorization = open_authorization(paypal_order)
      raise Spree::Core::GatewayError, no_authorization_message(paypal_order) if authorization.nil?

      result = protect_from_error(money_moving: true) do
        capture_authorization(authorization['id'], money, request_id: request_id(gateway_options, order_id, 'capture'))
      end

      case result['status']
      when 'COMPLETED' then success(order_id, result)
      when 'PENDING' then raise_pending_capture(result)
      else
        raise PaypalError.new(I18n.t('spree.paypal_checkout.errors.capture_not_completed', status: result['status']),
                              issue: result['status'])
      end
    end

    # Refunds the order's capture.
    #
    # @param money [Spree::Money]
    # @param order_id [String] the PayPal order id
    # @param options [Hash] carries the Spree::Refund as +originator+
    # @return [Spree::PaymentResponse] authorized by the PayPal refund id
    def credit(money, order_id, options = {})
      paypal_order = protect_from_error { paypal_order(order_id) }
      capture = captures(paypal_order).find { |candidate| candidate['status'].in?(CAPTURED_STATUSES) }
      raise Spree::Core::GatewayError, I18n.t('spree.paypal_checkout.errors.nothing_to_refund') if capture.nil?

      originator = options[:originator]
      # Without a refund record there is nothing stable to key on, and reusing
      # a key would replay an earlier refund instead of making this one.
      request_id = originator.respond_to?(:prefixed_id) ? "spree-#{originator.prefixed_id}-refund" : "paypal-#{SecureRandom.uuid}"

      result = protect_from_error(money_moving: true) do
        refund_capture(capture['id'], money, request_id: request_id)
      end

      success(result['id'], result)
    end

    # Releases the order's authorization. An order taken with the CAPTURE
    # intent holds no authorization until it is captured, so there is nothing
    # to release.
    #
    # @param order_id [String] the PayPal order id
    # @param gateway_options [Hash]
    # @return [Spree::PaymentResponse]
    # @raise [PaypalError] when a capture is still pending: the money may yet
    #   arrive, and a payment voided in Spree could not take it
    def void(order_id, gateway_options = {})
      paypal_order = protect_from_error { paypal_order(order_id) }

      capture = captures(paypal_order).first
      if capture && capture['status'] == 'PENDING'
        raise PaypalError.new(I18n.t('spree.paypal_checkout.errors.void_pending_capture'), issue: 'PENDING')
      end
      if capture && capture['status'].in?(CAPTURED_STATUSES)
        raise Spree::Core::GatewayError, I18n.t('spree.paypal_checkout.errors.void_captured')
      end

      authorization = open_authorization(paypal_order)
      return success(order_id, paypal_order) if authorization.nil?

      result = protect_from_error(money_moving: true) do
        void_authorization(authorization['id'], request_id: request_id(gateway_options, order_id, 'void'))
      end

      success(order_id, result)
    end

    # A completed payment can no longer be voided, so cancellation refunds it
    # instead, unless the operator asked to keep the money. Refunds for a
    # fulfillment are skipped; the delivery cost is refunded as a whole
    # elsewhere.
    def cancel(order_id, payment = nil, refund: true)
      return void(order_id, payment ? payment.gateway_options : {}) unless payment&.completed?
      return success(order_id, {}) unless refund

      amount = payment.credit_allowed
      return success(order_id, {}) if amount.zero?
      return success(order_id, {}) if payment.respond_to?(:for_shipment?) && payment.for_shipment?

      # Store passed explicitly: cancellation runs from jobs and webhooks where
      # Spree::Current.store is nil.
      result = Spree.refund_create_workflow.call(
        payment: payment,
        reason: Spree::RefundReason.order_canceled_reason(payment.owner.store),
        refunder: payment.order.canceler
      )
      raise Spree::Core::GatewayError, result.error.value.to_s if result.failure?

      # The authorization must stay the order id, or the refund id would
      # overwrite it.
      success(payment.response_code, result.value.response.params)
    end

    # @param order_id [String]
    # @return [Hash] the PayPal order, as PayPal writes it
    def paypal_order(order_id)
      client.orders.get_order('id' => order_id).data.to_hash
    end

    # @return [Hash] the capture
    def capture_authorization(authorization_id, money, request_id:)
      client.payments.capture_authorized_payment(
        'authorization_id' => authorization_id,
        'paypal_request_id' => request_id,
        'prefer' => 'return=representation',
        'body' => PaypalServerSdk::CaptureRequest.new(amount: paypal_money(money), final_capture: true)
      ).data.to_hash
    end

    # @return [Hash] the refund
    def refund_capture(capture_id, money, request_id:)
      client.payments.refund_captured_payment(
        'capture_id' => capture_id,
        'paypal_request_id' => request_id,
        'prefer' => 'return=representation',
        'body' => PaypalServerSdk::RefundRequest.new(amount: paypal_money(money))
      ).data.to_hash
    end

    # @return [Hash] the voided authorization; empty when PayPal answers
    #   without a body
    def void_authorization(authorization_id, request_id:)
      client.payments.void_payment(
        'authorization_id' => authorization_id,
        'paypal_request_id' => request_id,
        'prefer' => 'return=representation'
      ).data&.to_hash || {}
    end

    # Asks PayPal for an access token with the stored credentials, which is
    # how PayPal says whether it accepts them.
    #
    # @raise [PaypalServerSdk::APIException] when PayPal refuses them
    def request_access_token
      basic = ["#{preferred_client_id}:#{preferred_client_secret}"].pack('m0')
      client.o_auth_authorization.request_token('authorization' => "Basic #{basic}").data
    end

    # Rebuilt when the credentials change, since it carries them.
    #
    # @return [PaypalServerSdk::Client]
    def client
      fingerprint = [preferred_client_id, preferred_client_secret, preferred_test_mode]
      return @client if @client && @client_fingerprint == fingerprint

      @client_fingerprint = fingerprint
      @client = PaypalServerSdk::Client.new(
        client_credentials_auth_credentials: PaypalServerSdk::ClientCredentialsAuthCredentials.new(
          o_auth_client_id: preferred_client_id.to_s,
          o_auth_client_secret: preferred_client_secret.to_s
        ),
        environment: preferred_test_mode ? PaypalServerSdk::Environment::SANDBOX : PaypalServerSdk::Environment::PRODUCTION,
        timeout: 30,
        max_retries: 2,
        # Retrying a POST is safe only because every one that moves money
        # carries a PayPal-Request-Id; a PATCH only ever replaces the whole
        # purchase unit.
        retry_methods: %i[get post patch],
        logging_configuration: PaypalServerSdk::LoggingConfiguration.new(
          logger: Rails.logger,
          log_level: log_level,
          # Bodies carry buyer names, emails and addresses.
          request_logging_config: PaypalServerSdk::RequestLoggingConfiguration.new(log_body: false, log_headers: false),
          response_logging_config: PaypalServerSdk::ResponseLoggingConfiguration.new(log_body: false, log_headers: false)
        )
      )
    end

    private

    def read_back(gateway_options)
      payment = find_payment(gateway_options)
      return failure('Payment not found') if payment.blank?
      return failure('Payment is missing a PayPal order') if payment.response_code.blank?

      paypal_order = protect_from_error { paypal_order(payment.response_code) }
      return success(payment.response_code, paypal_order) if captures(paypal_order).any? || open_authorization(paypal_order)

      failure(no_authorization_message(paypal_order))
    end

    # Scoped through this gateway's own payments and found by the prefixed id;
    # the stored number remains only for callers still passing pre-6.0 options.
    def find_payment(gateway_options)
      prefixed_id = gateway_options[:payment_prefixed_id]
      payment = prefixed_id.present? ? payments.find_by_prefix_id(prefixed_id) : nil
      return payment if payment.present?

      payment_number = gateway_options[:payment_id].presence || gateway_options[:order_id]
      payments.find_by(number: payment_number) if payment_number.present?
    end

    def captures(paypal_order)
      payments_of(paypal_order, 'captures')
    end

    def open_authorization(paypal_order)
      payments_of(paypal_order, 'authorizations').find do |authorization|
        authorization['status'].in?(OPEN_AUTHORIZATION_STATUSES)
      end
    end

    def payments_of(paypal_order, kind)
      Array(paypal_order['purchase_units']).flat_map { |unit| Array(unit.dig('payments', kind)) }
    end

    def no_authorization_message(paypal_order)
      authorization = payments_of(paypal_order, 'authorizations').first
      if authorization
        I18n.t('spree.paypal_checkout.errors.authorization_not_open', status: authorization['status'])
      else
        I18n.t('spree.paypal_checkout.errors.nothing_to_capture', status: paypal_order['status'])
      end
    end

    def raise_pending_capture(capture)
      reason = capture.dig('status_details', 'reason') || 'PENDING'
      raise PaypalError.new(I18n.t('spree.paypal_checkout.errors.capture_pending', reason: reason), issue: reason)
    end

    # Keyed on the Spree payment, so a retry or a double click reaches PayPal
    # as the same request and cannot move money twice.
    def request_id(gateway_options, order_id, action)
      base = gateway_options[:idempotency_key].presence || "paypal-#{order_id}"
      "#{base}-#{action}"
    end

    def paypal_money(money)
      currency = money.currency.to_s.upcase
      PaypalServerSdk::Money.new(currency_code: currency, value: SpreePaypalCheckout::Amounts.to_paypal(money, currency))
    end

    def log_level
      Logger.const_get(ENV.fetch('PAYPAL_LOG_LEVEL', 'info').upcase)
    rescue NameError
      Logger::INFO
    end

    def credentials_changed?
      return false if preferred_client_id.blank? || preferred_client_secret.blank?

      new_record? || preferred_client_id_changed? || preferred_client_secret_changed? || preferred_test_mode_changed?
    end

    def validate_credentials
      request_access_token
    rescue PaypalServerSdk::APIException
      errors.add(:base, :credentials_rejected, message: credentials_rejected_message)
    rescue *CONNECTION_ERRORS
      errors.add(:base, :paypal_unavailable, message: I18n.t('spree.paypal_checkout.errors.paypal_unavailable'))
    end

    def credentials_rejected_message
      I18n.t('spree.paypal_checkout.errors.credentials_rejected', environment: preferred_test_mode ? 'sandbox' : 'live')
    end

    # PayPal's refusal becomes a GatewayError naming its issue code. A call
    # that moves money and gets no answer becomes an AmbiguousGatewayError,
    # since PayPal may have acted on it.
    def protect_from_error(money_moving: false)
      yield
    rescue PaypalServerSdk::ErrorException => e
      detail = e.details.is_a?(Array) ? e.details.first : nil
      issue = detail&.issue || e.name
      description = detail&.description || e.message
      raise PaypalError.new([issue, description].compact.join(': '), issue: issue)
    rescue PaypalServerSdk::APIException => e
      raise PaypalError, "PayPal: #{e.reason}"
    rescue CoreLibrary::AuthValidationException
      raise Spree::Core::GatewayError, credentials_rejected_message
    rescue *CONNECTION_ERRORS => e
      error_class = money_moving ? Spree::Core::AmbiguousGatewayError : Spree::Core::GatewayError
      raise error_class, I18n.t('spree.paypal_checkout.errors.no_answer', message: e.message)
    end

    def success(authorization, full_response)
      Spree::PaymentResponse.new(true, nil, full_response.as_json, authorization: authorization)
    end

    def failure(error = nil)
      Spree::PaymentResponse.new(false, error)
    end
  end
end
