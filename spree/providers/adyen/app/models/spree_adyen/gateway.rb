module SpreeAdyen
  # Adyen gateway built on the payment session API: Adyen's Sessions flow with
  # Drop-in. A session payment's response code is always its Adyen session id,
  # the key core links a session to its payment by; the PSP reference Adyen
  # needs for a capture, cancel or refund lives in the payment's metadata.
  class Gateway < ::Spree::Gateway
    self.accepts_money_amounts = true

    include SpreeAdyen::Gateway::PaymentSessions
    include SpreeAdyen::Gateway::PaymentSetupSessions

    # Typed by the operator.
    preference :api_key, :password
    preference :merchant_account, :string
    preference :test_mode, :boolean, default: true
    # Adyen's live Checkout endpoints need it; the Management API does not.
    preference :live_url_prefix, :string

    # Written by configuration after save, never by an operator.
    preference :client_key, :password, internal: true
    preference :hmac_key, :password, internal: true
    preference :previous_hmac_key, :password, internal: true
    preference :webhook_id, :string, internal: true

    # Explicit, instead of the library's 30 and 60 seconds; the read matches
    # PayPal's gateway.
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 30
    # A call that times out or gets a 5xx is retried this many times, with the
    # same idempotency key.
    RETRIES = 2
    CONNECTION_ERRORS = [Faraday::TimeoutError, Faraday::ConnectionFailed].freeze
    CREDENTIAL_PREFERENCES = %w[api_key merchant_account test_mode live_url_prefix].freeze

    validates :preferred_api_key, :preferred_merchant_account, presence: true
    validates :preferred_live_url_prefix, presence: true, unless: :preferred_test_mode
    validate :validate_credential, unless: -> { Rails.env.test? }, if: :credentials_changed?

    def self.logo_url
      'https://spreecommerce.org/docs/images/integrations/logos/adyen.png'
    end

    def self.docs_url
      'https://spreecommerce.org/docs/integrations/payments/adyen'
    end

    def provider_class
      self.class
    end

    def default_name
      'Adyen'
    end

    def method_type
      'spree_adyen'
    end

    def payment_icon_name
      'adyen'
    end

    def session_required?
      true
    end

    def payment_session_class
      Spree::PaymentSessions::Adyen
    end

    def payment_setup_session_class
      Spree::PaymentSetupSessions::Adyen
    end

    # Cards are saved under the customer's shopper reference, and core passes
    # the source to void and credit.
    def payment_profiles_supported?
      true
    end

    # Not offered for a currency missing from Adyen's currency table.
    def available_for_order?(order)
      super && SpreeAdyen::Amounts.supported?(order.currency)
    end

    # Adyen's Customer Area page for the payment's PSP reference.
    def gateway_dashboard_payment_url(payment)
      psp_reference = payment.metadata['adyen_psp_reference'].presence
      return if psp_reference.nil?

      "https://ca-#{environment}.adyen.com/ca/ca/accounts/showTx.shtml?pspReference=#{psp_reference}&txType=Payment"
    end

    # @return [String] 'test' or 'live'
    def environment
      preferred_test_mode ? 'test' : 'live'
    end

    # Called by core when a session-created payment moves on. Adyen already
    # holds the authorisation, so this makes no call.
    #
    # @return [Spree::PaymentResponse] authorized by the session id
    def authorize(_money, _source, gateway_options = {})
      payment = payment_from_options(gateway_options)
      raise Spree::Core::GatewayError, I18n.t('spree.adyen.errors.session_required') if payment&.payment_session.nil?

      success(payment.response_code)
    end

    # @see #authorize
    def purchase(money, source, gateway_options = {})
      authorize(money, source, gateway_options)
    end

    # Requests a capture of the payment's PSP reference. Adyen answers by
    # webhook, so the payment waits until it does.
    #
    # @param money [Spree::Money]
    # @param session_id [String] the payment's response code
    # @return [Spree::PaymentResponse] requested, with the capture's own PSP reference
    def capture(money, session_id, _gateway_options = {})
      payment = payment_for(session_id)
      psp_reference = psp_reference!(payment)
      body = { merchantAccount: preferred_merchant_account, amount: adyen_amount(money) }
      result = money_moving_call(payment, 'capture', payment.capture_events.count) do |client, headers, reference|
        client.checkout.modifications_api.capture_authorised_payment(body.merge(reference: reference), psp_reference, headers: headers)
      end

      success(session_id, requested: true, reference: result['pspReference'])
    end

    # Requests a cancel of the payment's authorisation, recording the cancel's
    # PSP reference so the next attempt gets a new idempotency key.
    #
    # @return [Spree::PaymentResponse] requested
    def void(session_id, _source = nil, _gateway_options = {})
      payment = payment_for(session_id)
      psp_reference = psp_reference!(payment)
      references = Array(payment.metadata['adyen_cancel_references'])
      result = money_moving_call(payment, 'cancel', references.size) do |client, headers, reference|
        client.checkout.modifications_api.cancel_authorised_payment_by_psp_reference(
          { merchantAccount: preferred_merchant_account, reference: reference }, psp_reference, headers: headers
        )
      end

      payment.update_columns(metadata: payment.metadata.merge('adyen_cancel_references' => references + [result['pspReference']]))
      success(session_id, requested: true)
    end

    # Requests a refund of the payment's PSP reference, keyed on the refund
    # rows the payment had before this one.
    #
    # @param options [Hash] carries the Spree::Refund as +originator+
    # @return [Spree::PaymentResponse] requested, authorized by the refund's PSP reference
    def credit(money, _source, session_id, options = {})
      payment = payment_for(session_id)
      refund = options[:originator]
      earlier_refunds = refund.is_a?(Spree::Refund) ? payment.refunds.where(id: ...refund.id).count : payment.refunds.count
      psp_reference = psp_reference!(payment)
      body = { merchantAccount: preferred_merchant_account, amount: adyen_amount(money) }
      result = money_moving_call(payment, 'refund', earlier_refunds) do |client, headers, reference|
        client.checkout.modifications_api.refund_captured_payment(body.merge(reference: reference), psp_reference, headers: headers)
      end

      success(result['pspReference'], requested: true)
    end

    # A completed payment is refunded, unless the operator asked to keep the
    # money; anything else is voided.
    def cancel(session_id, payment = nil, refund: true)
      return void(session_id) unless payment&.completed?
      return success(session_id) unless refund

      amount = payment.credit_allowed
      return success(session_id) if amount.zero?
      return success(session_id) if payment.respond_to?(:for_shipment?) && payment.for_shipment?

      # Store passed explicitly: cancellation runs from jobs and webhooks where
      # Spree::Current.store is nil.
      result = Spree.refund_create_workflow.call(
        payment: payment,
        reason: Spree::RefundReason.order_canceled_reason(payment.owner.store),
        refunder: payment.order&.canceler
      )
      raise Spree::Core::GatewayError, result.error.value.to_s if result.failure?

      success(session_id, requested: true)
    end

    # A captured payment is refunded instead.
    def can_void?(payment)
      !payment.completed?
    end

    # What is wrong with the credential, in words the operator can act on, or
    # nil when it reaches the merchant account with the roles the gem needs.
    #
    # @return [String, nil]
    def credential_problem
      merchants = adyen_call(:list_merchants) do |client|
        client.management.account_merchant_level_api.list_merchant_accounts(query_params: { pageSize: 100 })
      end
      reachable = Array(merchants['data']).pluck('id')
      unless reachable.include?(preferred_merchant_account)
        return I18n.t('spree.adyen.errors.merchant_account_unreachable', merchant_account: preferred_merchant_account)
      end

      adyen_call(:list_webhooks) do |client|
        client.management.webhooks_merchant_level_api.list_all_webhooks(preferred_merchant_account, query_params: { pageSize: 1 })
      end
      nil
    rescue CredentialRejected
      I18n.t('spree.adyen.errors.invalid_api_key')
    rescue RoleMissing
      I18n.t('spree.adyen.errors.role_missing')
    end

    # Adyen refused the API key.
    class CredentialRejected < Spree::Core::GatewayError; end
    # The API key lacks a role a call needs.
    class RoleMissing < Spree::Core::GatewayError; end

    # Calls Adyen through the library, retrying a timeout or a 5xx with the same
    # idempotency key. Logs status lines only: bodies carry names, emails and
    # addresses.
    #
    # @param operation [Symbol] named in the log line
    # @param money_moving [Boolean] a call still unanswered after its retries
    #   raises AmbiguousGatewayError, since Adyen may have acted on it
    # @yieldparam client [Adyen::Client]
    # @return [Hash] Adyen's answer, string keys
    def adyen_call(operation, money_moving: false)
      attempt = 0
      begin
        attempt += 1
        result = yield(adyen_client)
        log_status(operation, result.status)
        result.response.to_h.deep_stringify_keys
      rescue *CONNECTION_ERRORS, Adyen::ServerError => e
        log_status(operation, e.is_a?(Adyen::ServerError) ? e.code : e.class.name.demodulize)
        if attempt <= RETRIES
          wait_before_retry(attempt)
          retry
        end

        error_class = money_moving ? Spree::Core::AmbiguousGatewayError : Spree::Core::GatewayError
        raise error_class, I18n.t('spree.adyen.errors.no_answer', message: e.message.to_s.truncate(200))
      rescue Adyen::AdyenError => e
        log_status(operation, e.code)
        raise refusal(e)
      end
    end

    private

    def credentials_changed?
      return false if preferred_api_key.blank? || preferred_merchant_account.blank?

      new_record? || CREDENTIAL_PREFERENCES.any? { |key| public_send(:"preferred_#{key}_changed?") }
    end

    def validate_credential
      problem = credential_problem
      errors.add(:base, problem) if problem
    rescue Spree::Core::GatewayError => e
      errors.add(:base, e.message)
    end

    def adyen_client
      Adyen::Client.new(
        api_key: preferred_api_key,
        env: preferred_test_mode ? :test : :live,
        live_url_prefix: preferred_live_url_prefix.presence,
        connection_options: Faraday::ConnectionOptions.new(
          request: Faraday::RequestOptions.new(open_timeout: OPEN_TIMEOUT, timeout: READ_TIMEOUT)
        )
      )
    end

    def wait_before_retry(attempt)
      sleep(0.5 * (2**(attempt - 1)))
    end

    def log_status(operation, status)
      Rails.logger.info("[spree_adyen] #{operation} #{status}")
    end

    # Adyen's own error code and message, never the library's summary.
    def refusal(error)
      body = begin
        error.response.is_a?(String) ? JSON.parse(error.response) : error.response.to_h
      rescue JSON::ParserError
        {}
      end
      message = body['message'].presence || body['detail'].presence || error.msg.to_s
      code = body['errorCode'].presence
      text = I18n.t('spree.adyen.errors.refused', message: [message, code && "(#{code})"].compact.join(' '))

      case error
      when Adyen::AuthenticationError then CredentialRejected.new(text)
      when Adyen::PermissionError then RoleMissing.new(text)
      else Spree::Core::GatewayError.new(text)
      end
    end

    # The payment a session id names, among this method's own.
    def payment_for(session_id)
      # A payment core split off a partial capture has no session, and so no
      # PSP reference to ask Adyen about.
      raise Spree::Core::GatewayError, I18n.t('spree.adyen.errors.psp_reference_missing') if session_id.blank?

      payments.find_by!(response_code: session_id)
    rescue ActiveRecord::RecordNotFound
      raise Spree::Core::GatewayError, I18n.t('spree.adyen.errors.payment_not_found')
    end

    def payment_from_options(gateway_options)
      prefixed_id = gateway_options[:payment_prefixed_id].presence
      payments.find_by_prefix_id(prefixed_id) if prefixed_id
    end

    def psp_reference!(payment)
      payment.metadata['adyen_psp_reference'].presence ||
        raise(Spree::Core::GatewayError, I18n.t('spree.adyen.errors.psp_reference_missing'))
    end

    def adyen_amount(money)
      SpreeAdyen::Amounts.to_adyen_amount(money.to_d, money.currency.iso_code)
    end

    # A capture, cancel or refund keyed from Spree records, so the key repeats
    # only while the previous attempt's outcome is unknown and stays under
    # Adyen's 64 characters. Adyen answers a repeated key with its first answer
    # for days, so an attempt it refused is counted on the payment: the next
    # one gets a new key instead of the old refusal.
    #
    # The request's reference is the key behind the order number, so staff
    # find Spree's requests in the Customer Area, as with 5.x.
    #
    # @param attempt [Integer] the records the earlier answered attempts left
    # @yieldparam reference [String] for the request body's +reference+
    def money_moving_call(payment, action, attempt)
      refusals = payment.metadata.dig('adyen_refusals', action).to_i
      key = "spree-#{payment.prefixed_id}-#{action}-#{attempt + refusals}"
      reference = [payment.owner&.number, key].compact.join('-')
      adyen_call(action.to_sym, money_moving: true) { |client| yield(client, { 'Idempotency-Key' => key }, reference) }
    rescue Spree::Core::AmbiguousGatewayError
      raise
    rescue Spree::Core::GatewayError
      counted = (payment.metadata['adyen_refusals'] || {}).merge(action => refusals + 1)
      payment.update_columns(metadata: payment.metadata.merge('adyen_refusals' => counted))
      raise
    end

    def success(authorization, requested: false, reference: nil)
      Spree::PaymentResponse.new(true, 'Adyen accepted the request', {},
                                 authorization: authorization, requested: requested, reference: reference,
                                 test: preferred_test_mode)
    end
  end
end
