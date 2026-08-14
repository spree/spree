# spree_opentelemetry

Distributed tracing for [Spree Commerce](https://spreecommerce.org) via
[OpenTelemetry](https://opentelemetry.io).

With this gem installed, Spree exports traces as soon as the standard
OpenTelemetry environment variables point at a collector — no code changes:

```ruby
# Gemfile
gem 'spree_opentelemetry'
```

```bash
OTEL_SERVICE_NAME=spree
OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4318
```

Without an exporter configured, the gem stays dormant. `OTEL_SDK_DISABLED=true`
is the kill switch.

## What gets traced

- **Framework layers** via the official Rails auto-instrumentation: HTTP
  requests (Rack/Action Pack), database queries (Active Record), background
  jobs (Active Job, with trace context carried across the enqueue → perform
  boundary), mail delivery, outbound HTTP (Net::HTTP).
- **Spree commerce layers** via Spree's own notification surface: workflow
  runs and steps (external steps become `client` spans), extension hook
  dispatch, event subscriber dispatch, webhook deliveries (with W3C
  `traceparent` propagated to the receiving system), and payment gateway
  calls.

Span attributes never contain personal data — prefixed IDs, workflow/step
names, gateway action names, and HTTP metadata only.

See the [telemetry guide](https://docs.spreecommerce.org/developer/deployment/telemetry)
for the full span catalog, collector examples, and sampling guidance.

## Code-level configuration

Only needed for what env vars can't express:

```ruby
# config/initializers/opentelemetry.rb
SpreeOpenTelemetry.configure do |config|
  config.use 'OpenTelemetry::Instrumentation::Redis'          # extra instrumentation
  config.skip 'OpenTelemetry::Instrumentation::ActionMailer'  # drop a default
  config.with_sdk { |otel| otel.add_span_processor(my_processor) }
end
```

## License

Spree is released under the [New BSD License](https://github.com/spree/spree/blob/main/license.md).
