module SpreeOpenTelemetry
  # Code-level configuration, for the few things env vars can't express.
  # Set from a host initializer:
  #
  #   SpreeOpenTelemetry.configure do |config|
  #     config.service_name = 'storefront-api'
  #     config.use 'OpenTelemetry::Instrumentation::Redis'
  #     config.skip 'OpenTelemetry::Instrumentation::ActionMailer'
  #     config.with_sdk { |otel| otel.add_span_processor(my_processor) }
  #   end
  class Configuration
    DEFAULT_INSTRUMENTATIONS = {
      'OpenTelemetry::Instrumentation::Rack' => {},
      'OpenTelemetry::Instrumentation::ActionPack' => {},
      'OpenTelemetry::Instrumentation::ActionMailer' => {},
      'OpenTelemetry::Instrumentation::ActiveRecord' => {},
      'OpenTelemetry::Instrumentation::ActiveSupport' => {},
      # :link keeps a checkout trace from stretching until the last webhook
      # retry finishes — background work links to the enqueuing trace instead
      # of continuing it.
      'OpenTelemetry::Instrumentation::ActiveJob' => { propagation_style: :link },
      'OpenTelemetry::Instrumentation::ConcurrentRuby' => {},
      'OpenTelemetry::Instrumentation::Net::HTTP' => {},
    }.freeze

    # Force telemetry on/off regardless of exporter env vars; nil (default)
    # means env-driven activation.
    attr_accessor :enabled

    # Overrides OTEL_SERVICE_NAME when set.
    attr_accessor :service_name

    attr_reader :instrumentations, :sdk_hooks

    def initialize
      @enabled = nil
      @service_name = nil
      @instrumentations = DEFAULT_INSTRUMENTATIONS.transform_values(&:dup)
      @sdk_hooks = []
    end

    # Adds (or reconfigures) an instrumentation installed at SDK boot.
    #
    # @param name [String] instrumentation class name, e.g. 'OpenTelemetry::Instrumentation::Redis'
    # @param config [Hash] instrumentation-specific options
    def use(name, config = {})
      @instrumentations[name.to_s] = config
    end

    # Removes an instrumentation from the install list.
    def skip(name)
      @instrumentations.delete(name.to_s)
    end

    # Registers a block run inside OpenTelemetry::SDK.configure — the escape
    # hatch for samplers, extra span processors, resource attributes.
    def with_sdk(&block)
      @sdk_hooks << block
    end
  end
end
