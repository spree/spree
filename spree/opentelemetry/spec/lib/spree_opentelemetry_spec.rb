# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpreeOpenTelemetry do
  # enabled? reads ENV directly — manage the relevant keys per example and
  # restore them afterwards.
  around do |example|
    saved = %w[OTEL_SDK_DISABLED OTEL_EXPORTER_OTLP_ENDPOINT OTEL_EXPORTER_OTLP_TRACES_ENDPOINT OTEL_TRACES_EXPORTER]
            .index_with { |key| ENV[key] }
    saved.each_key { |key| ENV.delete(key) }
    example.run
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  after { described_class.instance_variable_set(:@configuration, nil) }

  describe '.enabled?' do
    it 'is dormant when no exporter is configured' do
      expect(described_class.enabled?).to be false
    end

    it 'activates when an OTLP endpoint is set' do
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://collector:4318'

      expect(described_class.enabled?).to be true
    end

    it 'activates when a traces exporter is named' do
      ENV['OTEL_TRACES_EXPORTER'] = 'otlp'

      expect(described_class.enabled?).to be true
    end

    it 'stays dormant when the traces exporter is explicitly none' do
      ENV['OTEL_TRACES_EXPORTER'] = 'none'

      expect(described_class.enabled?).to be false
    end

    it 'honors the OTEL_SDK_DISABLED kill switch over everything else' do
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://collector:4318'
      ENV['OTEL_SDK_DISABLED'] = 'true'

      expect(described_class.enabled?).to be false
    end

    it 'can be forced on from configuration without any env vars — the Sentry-OTLP-mode path' do
      described_class.configure { |config| config.enabled = true }

      expect(described_class.enabled?).to be true
    end
  end

  describe '.install!' do
    it 'does nothing while dormant' do
      expect(described_class.install!).to be false
      expect(described_class.installed?).to be false
    end
  end

  describe SpreeOpenTelemetry::Configuration do
    it 'ships the Rails instrumentation set with linked ActiveJob propagation' do
      configuration = described_class.new

      expect(configuration.instrumentations).to include(
        'OpenTelemetry::Instrumentation::Rack',
        'OpenTelemetry::Instrumentation::ActiveRecord',
        'OpenTelemetry::Instrumentation::Net::HTTP'
      )
      expect(configuration.instrumentations['OpenTelemetry::Instrumentation::ActiveJob'])
        .to eq(propagation_style: :link)
    end

    it 'supports adding and removing instrumentations' do
      configuration = described_class.new
      configuration.use 'OpenTelemetry::Instrumentation::Redis', peer_service: 'cache'
      configuration.skip 'OpenTelemetry::Instrumentation::ActionMailer'

      expect(configuration.instrumentations['OpenTelemetry::Instrumentation::Redis']).to eq(peer_service: 'cache')
      expect(configuration.instrumentations).not_to include('OpenTelemetry::Instrumentation::ActionMailer')
    end
  end
end
