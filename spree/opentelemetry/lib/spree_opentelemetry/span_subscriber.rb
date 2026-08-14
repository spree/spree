module SpreeOpenTelemetry
  # Turns one ActiveSupport::Notifications event into a span. Evented
  # (start/finish) rather than block-subscribed, so the span is current while
  # the instrumented work runs and children nest under it correctly. The span
  # handle rides in the notification payload — the same trick the upstream
  # ActiveSupport instrumentation uses.
  class SpanSubscriber
    PAYLOAD_KEY = :__spree_opentelemetry_span

    # Workflow control-flow signals inherit Exception by design (a plain
    # rescue must not swallow them). Halted is a successful early exit and
    # must not mark the span errored; FailureSignal is a real failure but is
    # not worth an exception event — the error status carries the verdict.
    HALT_EXCEPTIONS = %w[Spree::Workflow::Halted].freeze
    CONTROL_FLOW_EXCEPTIONS = %w[Spree::Workflow::FailureSignal Spree::Workflow::Halted].freeze

    # @param tracer [OpenTelemetry::Trace::Tracer]
    # @param name [Proc] payload -> span name
    # @param kind [Proc, nil] payload -> :internal/:client/…; defaults to :internal
    # @param attributes [Proc, nil] payload -> attribute hash (nil values dropped)
    # @param skip [Proc, nil] payload -> true suppresses the span entirely
    # @param error [Proc, nil] payload -> error message when the span failed
    #   without an exception (e.g. a failure result), nil otherwise
    def initialize(tracer:, name:, kind: nil, attributes: nil, skip: nil, error: nil)
      @tracer = tracer
      @name = name
      @kind = kind
      @attributes = attributes
      @skip = skip
      @error = error
    end

    # Instrumentation must never break the instrumented work: a raising
    # name/kind/attributes proc is reported through the OpenTelemetry error
    # handler instead of propagating, and finish/detach always run so a bad
    # proc cannot leak an unfinished span or a stuck context onto the thread.
    # @param _event_name [String] notification name (unused)
    # @param _id [String] notification instrumenter id (unused)
    # @param payload [Hash] notification payload; the span handle is stored on it
    # @return [void]
    def start(_event_name, _id, payload)
      return if @skip&.call(payload)

      span = @tracer.start_span(
        @name.call(payload),
        kind: @kind ? @kind.call(payload) : :internal
      )
      token = ::OpenTelemetry::Context.attach(::OpenTelemetry::Trace.context_with_span(span))
      payload[PAYLOAD_KEY] = [span, token]
    rescue StandardError => error
      ::OpenTelemetry.handle_error(exception: error, message: "SpreeOpenTelemetry failed to start span #{@name.inspect}")
      span&.finish if payload[PAYLOAD_KEY].nil?
    end

    # @param _event_name [String] notification name (unused)
    # @param _id [String] notification instrumenter id (unused)
    # @param payload [Hash] notification payload; the span handle is removed from it
    # @return [void]
    def finish(_event_name, _id, payload)
      span, token = payload.delete(PAYLOAD_KEY)
      return unless span

      begin
        @attributes&.call(payload)&.each do |key, value|
          span.set_attribute(key, value) unless value.nil?
        end
        record_outcome(span, payload)
      rescue StandardError => error
        ::OpenTelemetry.handle_error(exception: error, message: 'SpreeOpenTelemetry failed to finalize span')
      ensure
        span.finish
        ::OpenTelemetry::Context.detach(token)
      end
    end

    private

    def record_outcome(span, payload)
      exception = payload[:exception_object]

      if exception && !HALT_EXCEPTIONS.include?(exception.class.name)
        span.record_exception(exception) unless CONTROL_FLOW_EXCEPTIONS.include?(exception.class.name)
        span.status = ::OpenTelemetry::Trace::Status.error(exception.message.to_s)
      elsif (message = @error&.call(payload))
        span.status = ::OpenTelemetry::Trace::Status.error(message.to_s)
      end
    end
  end
end
