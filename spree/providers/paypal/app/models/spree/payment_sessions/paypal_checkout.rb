module Spree
  # Stored under this name in `type` columns since 5.x, so it is kept.
  class PaymentSessions::PaypalCheckout < PaymentSession
    # The order read at completion, or by prepare_for_settlement! on the
    # webhook path, so settlement inside the lock does no PayPal I/O.
    attr_writer :paypal_order

    def intent
      external_data&.dig('intent')
    end

    # Moves only after a recoverable decline, so a buyer's next try reaches
    # PayPal as a new request rather than a replay of the declined one.
    #
    # @return [Integer]
    def attempt
      (external_data&.dig('attempt') || 1).to_i
    end

    # Whether Complete ever asked PayPal to move money for this session.
    def complete_attempted?
      external_data.present? && (external_data.key?('attempt') || external_data.key?('paypal_result'))
    end

    # @return [Hash]
    def paypal_order
      @paypal_order ||= payment_method.paypal_order(external_id)
    end

    # Settlement reads the order only to create the payment, so a session that
    # already has one needs no PayPal call.
    def prepare_for_settlement!
      paypal_order if payment.nil?
      self
    end

    # @return [SpreePaypalCheckout::PaymentSources::Paypal, nil]
    def payment_source_for_settlement
      SpreePaypalCheckout::PaymentSources::Paypal.for_payment_source(
        paypal_order['payment_source'],
        payment_method: payment_method,
        customer: owner&.customer,
        paypal_order_id: external_id
      )
    end

    # Records what PayPal issued against the order, which refunds and the
    # dashboard link cannot read from the order id alone.
    def apply_settlement_metadata(payment, metadata)
      super

      capture = payment_method.captures(paypal_order).first
      authorization = payment_method.authorizations(paypal_order).first
      payment.metadata['paypal_capture_id'] = capture['id'] if capture
      payment.metadata['paypal_authorization_id'] = authorization['id'] if authorization
    end
  end
end
