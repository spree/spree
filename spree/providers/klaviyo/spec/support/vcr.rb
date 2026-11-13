require 'vcr'
require 'webmock/rspec'

WebMock.disable_net_connect!(net_http_connect_on_start: true, allow_localhost: true)

VCR.configure do |c|
  c.allow_http_connections_when_no_cassette = false
  c.cassette_library_dir = File.join(SpreeKlaviyo::Engine.root, 'spec', 'vcr')
  c.hook_into :webmock
  c.ignore_localhost = true
  c.configure_rspec_metadata!

  # Offline by default: a missing cassette fails the example rather than quietly
  # recording one against whatever credentials happen to be in the environment.
  # Opt in with RECORD_VCR=1 when you genuinely intend to capture new interactions.
  # Klaviyo may compress its responses, which the filters below cannot see
  # into, so bodies are stored decompressed.
  c.default_cassette_options = {
    record: ENV['RECORD_VCR'] ? :new_episodes : :none,
    match_requests_on: %i[method klaviyo_route],
    decode_compressed_response: true
  }

  # Klaviyo ids in the path (a list, a profile) differ between the objects a
  # recording used and the placeholders a replay passes, so they are matched
  # as one segment.
  c.register_request_matcher :klaviyo_route do |recorded, replayed|
    route = ->(request) { URI(request.uri).path.sub(%r{\A(/api/[a-z-]+)/[^/]+}, '\1/:id') }
    route.call(recorded) == route.call(replayed)
  end

  c.filter_sensitive_data('<KLAVIYO_PRIVATE_API_KEY>') { ENV.fetch('KLAVIYO_PRIVATE_API_KEY', nil) }
  c.filter_sensitive_data('<KLAVIYO_LIMITED_API_KEY>') { ENV.fetch('KLAVIYO_LIMITED_API_KEY', nil) }

  # The inbox is filtered by its two halves, because the addresses put a plus tag between them.
  c.filter_sensitive_data('<KLAVIYO_TEST_INBOX_USER>') { ENV['KLAVIYO_TEST_INBOX']&.split('@', 2)&.first }
  c.filter_sensitive_data('<KLAVIYO_TEST_INBOX_DOMAIN>') { ENV['KLAVIYO_TEST_INBOX']&.split('@', 2)&.last }

  c.before_record do |interaction|
    # Klaviyo authenticates with `Authorization: Klaviyo-API-Key <key>`, which
    # a key not in the environment above would otherwise leave in place.
    Array(interaction.request.headers['Authorization']).each do |header|
      interaction.filter!(header, header.sub(/\AKlaviyo-API-Key .+\z/, 'Klaviyo-API-Key <FILTERED>'))
    end
  end
end
