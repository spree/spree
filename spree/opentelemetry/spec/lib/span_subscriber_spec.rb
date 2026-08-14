# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpreeOpenTelemetry::SpanSubscriber do
  def with_subscriber(subscriber, event_name)
    subscription = ActiveSupport::Notifications.subscribe(event_name, subscriber)
    yield
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  it 'finishes the span and detaches the context even when an attributes proc raises' do
    subscriber = described_class.new(
      tracer: SpreeOpenTelemetry.tracer,
      name: ->(_payload) { 'fragile' },
      attributes: ->(_payload) { raise 'attribute proc bug' }
    )
    handled = []
    allow(OpenTelemetry).to receive(:handle_error) { |**kwargs| handled << kwargs }

    result = nil
    with_subscriber(subscriber, 'fragile.test') do
      result = ActiveSupport::Notifications.instrument('fragile.test') { :ran }
    end

    expect(result).to eq(:ran)
    expect(handled).not_to be_empty
    span = SPREE_OTEL_TEST_EXPORTER.finished_spans.sole
    expect(span.name).to eq('fragile')
    expect(OpenTelemetry::Trace.current_span).to eq(OpenTelemetry::Trace::Span::INVALID)
  end

  it 'never lets a raising name proc break the instrumented work' do
    subscriber = described_class.new(
      tracer: SpreeOpenTelemetry.tracer,
      name: ->(_payload) { raise 'name proc bug' }
    )
    allow(OpenTelemetry).to receive(:handle_error)

    result = nil
    with_subscriber(subscriber, 'fragile.test') do
      result = ActiveSupport::Notifications.instrument('fragile.test') { :ran }
    end

    expect(result).to eq(:ran)
    expect(OpenTelemetry).to have_received(:handle_error)
    expect(OpenTelemetry::Trace.current_span).to eq(OpenTelemetry::Trace::Span::INVALID)
  end
end
