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
  # Walked at every depth: a company listing carries the account id per company.
  redact = lambda do |node|
    case node
    when Hash
      %w[authenticatedAccountId authenticatedUserId accountId createdUserId modifiedUserId].each do |field|
        node[field] = 0 if node.key?(field)
      end
      %w[authenticatedUserName crmid taxpayerIdNumber].each { |field| node[field] = 'redacted' if node.key?(field) }
      node.each_value { |value| redact.call(value) }
    when Array
      node.each { |value| redact.call(value) }
    end
  end

  c.before_record do |interaction|
    body = interaction.response.body.to_s
    next if body.blank?

    parsed = begin
      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end
    next unless parsed.is_a?(Hash)

    redact.call(parsed)

    interaction.response.body = JSON.generate(parsed)
  end
end
