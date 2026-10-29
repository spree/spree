require 'vcr'
require 'webmock/rspec'

WebMock.disable_net_connect!(net_http_connect_on_start: true, allow_localhost: true)

VCR.configure do |c|
  c.allow_http_connections_when_no_cassette = false
  c.cassette_library_dir = File.join(SpreePaypalCheckout::Engine.root, 'spec', 'vcr')
  c.hook_into :webmock
  c.ignore_localhost = true
  c.configure_rspec_metadata!

  # Offline by default: a missing cassette fails the example rather than quietly
  # recording one against whatever credentials happen to be in the environment.
  # Opt in with RECORD_VCR=1 when you genuinely intend to capture new interactions.
  c.default_cassette_options = { record: ENV['RECORD_VCR'] ? :new_episodes : :none }

  c.filter_sensitive_data('<PAYPAL_CLIENT_ID>') { ENV['PAYPAL_CLIENT_ID'] }
  c.filter_sensitive_data('<PAYPAL_CLIENT_SECRET>') { ENV['PAYPAL_CLIENT_SECRET'] }

  c.before_record do |interaction|
    # The token request carries the credentials as Basic auth and every other
    # call the access token as Bearer; neither is caught by the filters above.
    Array(interaction.request.headers['Authorization']).each do |header|
      interaction.filter!(header, header.sub(/\A(Basic|Bearer) .+\z/, '\1 <FILTERED>'))
    end

    # The token response hands the access token back in its body.
    interaction.response.body = interaction.response.body&.gsub(
      /"access_token"\s*:\s*"[^"]+"/, '"access_token":"<PAYPAL_ACCESS_TOKEN>"'
    )
  end
end
