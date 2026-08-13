require 'spree_core'

require 'opentelemetry/sdk'
require 'opentelemetry-exporter-otlp'
require 'opentelemetry-instrumentation-rack'
require 'opentelemetry-instrumentation-action_pack'
require 'opentelemetry-instrumentation-action_mailer'
require 'opentelemetry-instrumentation-active_record'
require 'opentelemetry-instrumentation-active_support'
require 'opentelemetry-instrumentation-active_job'
require 'opentelemetry-instrumentation-concurrent_ruby'
require 'opentelemetry-instrumentation-net_http'

require 'spree_opentelemetry/configuration'
require 'spree_opentelemetry/span_subscriber'
require 'spree_opentelemetry/subscribers'
require 'spree_opentelemetry/webhook_trace_propagation'
require 'spree_opentelemetry/engine'

# Optional OpenTelemetry support for Spree (docs/plans/6.0-opentelemetry.md).
#
# Activation is environment-driven, the way an SRE configures any other
# OpenTelemetry service: with the gem installed, traces flow as soon as a
# standard OTEL_* exporter variable is set, and nothing happens without one.
# `SpreeOpenTelemetry.configure` exists only for code-level needs (extra
# instrumentations, custom samplers) — telemetry is deployment configuration,
# never store data.
module SpreeOpenTelemetry
  # Env vars whose presence opts this process into exporting traces —
  # signal-specific endpoint first, matching the SDK's own precedence.
  EXPORTER_ENV_KEYS = %w[
    OTEL_EXPORTER_OTLP_TRACES_ENDPOINT
    OTEL_EXPORTER_OTLP_ENDPOINT
  ].freeze

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    # Whether telemetry should activate in this process. Dormant unless an
    # exporter is configured through the standard OpenTelemetry env vars (or
    # forced on via `configure { |c| c.enabled = true }` — the path
    # integrations like Sentry's OTLP mode use, since they register their own
    # exporter); OTEL_SDK_DISABLED is the kill switch and always wins.
    #
    # @return [Boolean]
    def enabled?
      return false if ENV['OTEL_SDK_DISABLED'] == 'true'
      return configuration.enabled unless configuration.enabled.nil?
      return true if EXPORTER_ENV_KEYS.any? { |key| !ENV[key].to_s.empty? }

      exporter = ENV['OTEL_TRACES_EXPORTER'].to_s
      !exporter.empty? && exporter != 'none'
    end

    def installed?
      @installed == true
    end

    # Boots the OpenTelemetry SDK and attaches the Spree span subscribers.
    # No-op when {#enabled?} is false — the opentelemetry-api layer stays a
    # zero-cost no-op in that case. Idempotent.
    #
    # @return [Boolean] whether telemetry is installed after the call
    def install!
      return true if installed?
      return false unless enabled?

      ::OpenTelemetry::SDK.configure do |otel_config|
        otel_config.service_name = configuration.service_name if configuration.service_name
        configuration.instrumentations.each do |instrumentation_name, instrumentation_config|
          otel_config.use(instrumentation_name, instrumentation_config)
        end
        configuration.sdk_hooks.each { |hook| hook.call(otel_config) }
      end

      Subscribers.attach!
      @installed = true
      log_activation
      true
    end

    # @return [OpenTelemetry::Trace::Tracer] the tracer Spree spans are created on
    def tracer
      version = defined?(Spree) && Spree.respond_to?(:version) ? Spree.version : nil
      ::OpenTelemetry.tracer_provider.tracer('spree', version)
    end

    # Test-only: forget installation state and configuration.
    def reset!
      Subscribers.detach!
      @installed = nil
      @configuration = nil
    end

    private

    def log_activation
      return unless defined?(Rails) && Rails.logger

      exporter = ENV['OTEL_TRACES_EXPORTER'].to_s.empty? ? 'otlp' : ENV['OTEL_TRACES_EXPORTER']
      endpoint = EXPORTER_ENV_KEYS.filter_map { |key| ENV[key] unless ENV[key].to_s.empty? }.first || '(default)'
      Rails.logger.info "[Spree OpenTelemetry] traces active — exporter=#{exporter} endpoint=#{endpoint}"
    end
  end
end
