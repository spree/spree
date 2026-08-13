# frozen_string_literal: true

module Spree
  # Marks a payment-gateway network call for tracing subscribers via the
  # 'gateway.spree_payments' notification. The payload is PII-safe by
  # design — gateway action and payment method class only; never amounts,
  # sources, credentials, or gateway responses.
  module InstrumentsGatewayCalls
    private

    def instrument_gateway_call(action, payment_method, &block)
      ActiveSupport::Notifications.instrument(
        'gateway.spree_payments',
        action: action.to_s,
        payment_method_type: payment_method&.type,
        &block
      )
    end
  end
end
