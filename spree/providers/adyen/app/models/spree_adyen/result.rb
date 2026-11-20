module SpreeAdyen
  # One report from Adyen about a session's payment, normalized: a session
  # result (GET /sessions/{id}), a /payments/details answer, or an AUTHORISATION
  # webhook item. Settlement reads only this, so the synchronous and webhook
  # paths cannot drift.
  class Result
    include ActiveModel::Model
    include ActiveModel::Attributes

    # Session statuses Adyen reports for GET /sessions/{id}.
    SESSION_COMPLETED = 'completed'.freeze
    SESSION_PAYMENT_PENDING = 'paymentPending'.freeze
    # Payment result codes that mean the money is held or on its way.
    AUTHORISED = 'Authorised'.freeze
    PENDING_CODES = %w[Received Pending].freeze

    attribute :psp_reference, :string
    attribute :result_code, :string
    attribute :session_status, :string
    attribute :amount, :decimal
    attribute :currency, :string
    attribute :variant, :string
    attribute :card_summary, :string
    attribute :expiry_month, :string
    attribute :expiry_year, :string
    attribute :stored_payment_method_id, :string
    attribute :merchant_reference, :string
    attribute :refusal_reason, :string
    attribute :payments_count, :integer

    # @param body [Hash] Adyen's answer to GET /sessions/{id}?sessionResult=
    # @return [Result]
    def self.from_session_result(body)
      body = body.to_h.deep_stringify_keys
      payments = Array(body['payments'])
      payment = payments.first || {}
      additional_data = payment['additionalData'] || body['additionalData'] || {}

      new(
        **report_attributes(payment, additional_data),
        session_status: body['status'],
        merchant_reference: body['reference'],
        payments_count: payments.size
      )
    end

    # @param body [Hash] Adyen's answer to POST /payments/details
    # @return [Result]
    def self.from_payment_details(body)
      body = body.to_h.deep_stringify_keys

      new(
        **report_attributes(body, body['additionalData'] || {}),
        merchant_reference: body['merchantReference'],
        payments_count: body['pspReference'].present? ? 1 : 0
      )
    end

    # @param item [Hash] a webhook's NotificationRequestItem
    # @return [Result]
    def self.from_notification(item)
      item = item.to_h.deep_stringify_keys
      additional_data = item['additionalData'] || {}
      amount = item['amount'] || {}
      success = item['success'].to_s == 'true'

      new(
        psp_reference: item['pspReference'],
        result_code: success ? AUTHORISED : 'Refused',
        amount: amount_from(amount),
        currency: amount['currency'],
        variant: additional_data['paymentMethodVariant'].presence || item['paymentMethod'],
        **card_attributes(additional_data),
        merchant_reference: item['merchantReference'],
        # A successful authorisation's reason is authCode:last4:expiry, not a refusal.
        refusal_reason: (item['reason'] unless success),
        payments_count: 1
      )
    end

    # @param hash [Hash] what {#to_h} wrote
    # @return [Result]
    def self.from_h(hash)
      attributes = hash.to_h.stringify_keys.slice(*attribute_names)
      new(**attributes.symbolize_keys)
    end

    def self.report_attributes(report, additional_data)
      amount = report['amount'] || {}
      payment_method = report['paymentMethod'] || {}

      {
        psp_reference: report['pspReference'],
        result_code: report['resultCode'],
        amount: amount_from(amount),
        currency: amount['currency'],
        variant: variant_from(payment_method, additional_data),
        refusal_reason: report['refusalReason'],
        **card_attributes(additional_data)
      }
    end

    # Cards report `scheme` (or a wallet) as their type and the network as
    # their brand; a wallet card's brand already carries the wallet suffix.
    def self.variant_from(payment_method, additional_data)
      return additional_data['paymentMethodVariant'] if additional_data['paymentMethodVariant'].present?
      return payment_method.to_s if payment_method.is_a?(String)

      type = payment_method['type'].to_s
      brand = payment_method['brand'].to_s
      return type if brand.blank?
      return "#{brand}_#{type}" if SpreeAdyen::Variants::WALLETS.key?(type) && !brand.end_with?("_#{type}")

      brand
    end

    def self.amount_from(amount)
      SpreeAdyen::Amounts.from_adyen(amount['value'], amount['currency']) if amount['value'] && amount['currency']
    end

    def self.card_attributes(additional_data)
      month, year = additional_data['expiryDate'].to_s.split('/')

      {
        card_summary: additional_data['cardSummary'],
        expiry_month: month,
        expiry_year: year,
        stored_payment_method_id: additional_data['tokenization.storedPaymentMethodId'].presence ||
          additional_data['recurring.recurringDetailReference'].presence
      }
    end
    private_class_method :report_attributes, :variant_from, :amount_from, :card_attributes

    # Adyen holds the money (or will): settle the session.
    def settleable?
      authorised? || pending?
    end

    def authorised?
      result_code == AUTHORISED || session_status == SESSION_COMPLETED
    end

    def pending?
      result_code.in?(PENDING_CODES) || session_status == SESSION_PAYMENT_PENDING
    end

    # JSON-safe with string keys: it crosses a background job as webhook
    # metadata and lands in the session's settlement hooks.
    #
    # @return [Hash{String => String, Integer, nil}]
    def to_h
      attributes.transform_values { |value| value.is_a?(BigDecimal) ? value.to_s('F') : value }
    end
  end
end
