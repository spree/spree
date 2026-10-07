# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
# Keep the SDK from wiring the default OTLP exporter in tests — spans go to
# the in-memory exporter below.
ENV['OTEL_TRACES_EXPORTER'] ||= 'none'

begin
  require File.expand_path('../dummy/config/environment', __FILE__)
rescue LoadError
  puts 'Could not load dummy application. Please ensure you have run `bundle exec rake test_app`'
end

require 'rspec/rails'
require 'database_cleaner/active_record'

require 'spree/testing_support/factories'
require 'spree/testing_support/jobs'
require 'spree/testing_support/store'

SPREE_OTEL_TEST_EXPORTER = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new

OpenTelemetry::SDK.configure do |otel_config|
  otel_config.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(SPREE_OTEL_TEST_EXPORTER)
  )
end

RSpec.configure do |config|
  config.color = true
  config.default_formatter = 'progress'
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec
  config.raise_errors_for_deprecations!
  config.use_transactional_fixtures = true

  config.include FactoryBot::Syntax::Methods

  config.before { SPREE_OTEL_TEST_EXPORTER.reset }

  config.order = :random
  Kernel.srand config.seed
end
