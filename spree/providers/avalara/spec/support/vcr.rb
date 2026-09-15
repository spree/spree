require 'vcr'
require 'webmock/rspec'

WebMock.disable_net_connect!(net_http_connect_on_start: true, allow_localhost: true)

# Cassettes are recorded by the maintainer against an AvaTax sandbox account and
# are never hand-authored: `record: :none` makes an unmatched request fail loudly
# instead of quietly reaching Avalara from a test run. To re-record, delete the
# cassette and run with VCR_RECORD_MODE=new_episodes and the AVATAX_* credentials
# set.
VCR.configure do |c|
  c.allow_http_connections_when_no_cassette = false
  c.cassette_library_dir = File.join(SpreeAvalara::Engine.root, 'spec', 'vcr')
  c.hook_into :webmock
  c.ignore_localhost = true
  c.configure_rspec_metadata!
  c.default_cassette_options = { record: ENV.fetch('VCR_RECORD_MODE', 'none').to_sym }

  # The company code is not a secret, but it identifies the merchant's Avalara
  # account and travels inside request paths. The stand-in has to be URL-safe and
  # has to be what specs use when the environment is unset, or a recorded URL can
  # never be matched again.
  c.filter_sensitive_data('AVALARA_COMPANY') { ENV['AVATAX_COMPANY_CODE'] }
  c.filter_sensitive_data('<AVATAX_LICENSE_KEY>') { ENV['AVATAX_LICENSE_KEY'] }
  c.filter_sensitive_data('<AVATAX_AUTHORIZATION>') do |interaction|
    interaction.request.headers['Authorization']&.first
  end

  # Account identifiers come back as numbers as well as strings, so they are
  # rewritten inside the parsed body rather than substituted as text. Replacing
  # a numeric field with a placeholder leaves invalid JSON, and a cassette that
  # no longer parses does not fail loudly — it reads as "not authenticated".
  c.before_record do |interaction|
    body = interaction.response.body.to_s
    next if body.blank?

    parsed = begin
      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end
    next unless parsed.is_a?(Hash)

    %w[authenticatedAccountId authenticatedUserId].each { |field| parsed[field] = 0 if parsed.key?(field) }
    %w[authenticatedUserName crmid].each { |field| parsed[field] = 'redacted' if parsed.key?(field) }

    interaction.response.body = JSON.generate(parsed)
  end
end

module SpreeAvalara
  module CassetteSkipping
    # Cassettes describe what Avalara actually returns, and only the maintainer
    # can record them against a sandbox account. An example whose cassette has
    # not been recorded yet skips rather than fails, so the suite stays green
    # while the gem is built out.
    def skip_without_cassette(name)
      # While recording, an absent cassette is the point — skipping would make
      # it impossible to ever create one.
      return if VCR.configuration.default_cassette_options[:record] != :none
      return if File.exist?(File.join(VCR.configuration.cassette_library_dir, "#{name}.yml"))

      skip("cassette #{name}.yml has not been recorded yet")
    end
  end
end

RSpec.configure do |config|
  config.include SpreeAvalara::CassetteSkipping

  config.before(:each, :vcr) do |example|
    metadata = example.metadata[:vcr]
    name = metadata.is_a?(Hash) ? metadata[:cassette_name] : nil

    skip_without_cassette(name) if name.present?
  end
end
