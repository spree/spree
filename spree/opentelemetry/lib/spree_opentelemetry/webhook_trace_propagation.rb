module SpreeOpenTelemetry
  # DeliverWebhook header decorator — injects W3C trace context
  # (traceparent/tracestate) into outbound webhook requests so the merchant's
  # receiving system can join the trace.
  module WebhookTracePropagation
    def self.call(headers, _delivery)
      ::OpenTelemetry.propagation.inject(headers)
    end
  end
end
