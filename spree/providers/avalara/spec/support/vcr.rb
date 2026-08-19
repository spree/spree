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

  c.filter_sensitive_data('<AVATAX_ACCOUNT_NUMBER>') { ENV['AVATAX_ACCOUNT_NUMBER'] }
  c.filter_sensitive_data('<AVATAX_LICENSE_KEY>') { ENV['AVATAX_LICENSE_KEY'] }
  c.filter_sensitive_data('<AVATAX_AUTHORIZATION>') do |interaction|
    interaction.request.headers['Authorization']&.first
  end

  # AvaTax echoes the account's own user name back in the ping response, so it
  # has to come out of the body as well as the request headers.
  c.filter_sensitive_data('<AVATAX_USERNAME>') do |interaction|
    begin
      JSON.parse(interaction.response.body.to_s)['authenticatedUserName']
    rescue JSON::ParserError
      nil
    end
  end
end

module SpreeAvalara
  module CassetteSkipping
    # Cassettes describe what Avalara actually returns, and only the maintainer
    # can record them against a sandbox account. An example whose cassette has
    # not been recorded yet skips rather than fails, so the suite stays green
    # while the gem is built out.
    def skip_without_cassette(name)
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
