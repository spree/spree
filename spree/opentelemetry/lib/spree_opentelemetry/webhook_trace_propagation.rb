module SpreeOpenTelemetry
  # DeliverWebhook header decorator — injects W3C trace context
  # (traceparent/tracestate) into outbound webhook requests so the merchant's
  # receiving system can join the trace.
  module WebhookTracePropagation
    # Trace context only, never the process-global propagator: that one is a
    # composite that also injects W3C baggage, and baggage carries arbitrary
    # application context to whatever third-party endpoint the merchant
    # configured.
    #
    # @param headers [Hash] outbound request headers, mutated in place
    # @param _delivery [Spree::WebhookDelivery] unused; part of the decorator contract
    # @return [Hash] the same headers hash
    def self.call(headers, _delivery)
      ::OpenTelemetry::Trace::Propagation::TraceContext.text_map_propagator.inject(headers)
      headers
    end
  end
end
