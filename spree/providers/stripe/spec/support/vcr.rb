require 'vcr'
require 'webmock/rspec'

WebMock.disable_net_connect!(net_http_connect_on_start: true, allow_localhost: true)

VCR.configure do |c|
  c.allow_http_connections_when_no_cassette = false
  c.cassette_library_dir = File.join(SpreeStripe::Engine.root, 'spec', 'vcr')
  c.hook_into :webmock
  c.ignore_localhost = true
  c.configure_rspec_metadata!

  # Offline by default: a missing cassette fails the example rather than quietly
  # recording one against whatever credentials happen to be in the environment.
  # Renaming a `:vcr` example changes its cassette path, so recording-by-default
  # turns a rename into a live API call. Opt in with RECORD_VCR=1 when you
  # genuinely intend to capture new interactions.
  c.default_cassette_options = { record: ENV['RECORD_VCR'] ? :new_episodes : :none }

  c.filter_sensitive_data('<STRIPE_PUBLISHABLE_KEY>') { ENV['STRIPE_PUBLISHABLE_KEY'] }
  c.filter_sensitive_data('<STRIPE_SECRET_KEY>') { ENV['STRIPE_SECRET_KEY'] }

  c.before_record do |interaction|
    # Carries the account's Stripe client fingerprint.
    headers = interaction.request.headers['X-Stripe-Client-User-Agent']
    Array(headers).each { |header| interaction.filter!(header, '<FILTERED>') }

    # Creating a webhook endpoint returns its signing secret in the response
    # body — a credential the request-side key filters never see.
    interaction.response.body = interaction.response.body&.gsub(
      /whsec_[A-Za-z0-9]+/, '<STRIPE_WEBHOOK_SIGNING_SECRET>'
    )
  end
end
