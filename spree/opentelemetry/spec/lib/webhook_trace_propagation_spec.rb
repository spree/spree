# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpreeOpenTelemetry::WebhookTracePropagation do
  it 'injects W3C trace context into outbound webhook headers' do
    headers = { 'Content-Type' => 'application/json' }

    SpreeOpenTelemetry.tracer.in_span('outer') do
      described_class.call(headers, nil)
    end

    expect(headers['traceparent']).to match(/\A00-\h{32}-\h{16}-\h{2}\z/)
    expect(headers['Content-Type']).to eq('application/json')
  end

  it 'is a no-op outside any trace' do
    headers = {}

    described_class.call(headers, nil)

    expect(headers).not_to have_key('traceparent')
  end
end
