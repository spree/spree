require 'vcr'
require 'webmock/rspec'

WebMock.disable_net_connect!(net_http_connect_on_start: true, allow_localhost: true)

# Recording (RECORD_VCR=1) reads the test account from the environment:
#
#   ADYEN_API_KEY             an API credential with Checkout access and the Management roles
#   ADYEN_MERCHANT_ACCOUNT    the merchant account it reaches
#   ADYEN_LIMITED_API_KEY     a second credential without the Webhooks roles (credential_missing_role)
#   ADYEN_UNREACHABLE_MERCHANT_ACCOUNT  a merchant account the first credential cannot reach (merchants_unreachable)
#   ADYEN_CAPTURE_PSP_REFERENCE   an authorised manual-capture payment (capture_received, cancel_received)
#   ADYEN_CAPTURED_PSP_REFERENCE  a payment captured through a capture request (capture_captured_received,
#                                 cancel_captured_received, refund_*); Adyen accepts all of these and
#                                 answers the impossible ones later, by webhook
#   ADYEN_PAID_SESSION_ID / ADYEN_PAID_SESSION_RESULT            a session paid by card through Drop-in, for 884.99
#   ADYEN_SAVED_CARD_SESSION_ID / ADYEN_SAVED_CARD_SESSION_RESULT a session paid with "Save for my next payment" ticked, for 884.99
#   ADYEN_PAYABLE_SESSION_ID / ADYEN_PAYABLE_SESSION_DATA        a session already made payable, for 124.99
#   ADYEN_AUTHORISED_REDIRECT_RESULT / ADYEN_REFUSED_REDIRECT_RESULT  redirect results, an authorised one for
#                                 94.99 under reference cart_p6klVeMgbn-3 and a refused one
#   ADYEN_LEGACY_WEBHOOK_ID   a webhook on .../adyen/webhooks (configure_legacy_webhook_url)
#
# The amounts, references and ids a replay must match are pinned in the specs,
# so a re-recording with other payments updates them there too.
VCR.configure do |c|
  c.allow_http_connections_when_no_cassette = false
  c.cassette_library_dir = File.join(SpreeAdyen::Engine.root, 'spec', 'vcr')
  c.hook_into :webmock
  c.ignore_localhost = true
  c.configure_rspec_metadata!

  # Offline by default: a missing cassette fails the example rather than quietly
  # recording one against whatever credentials happen to be in the environment.
  # Opt in with RECORD_VCR=1 when you genuinely intend to capture new interactions.
  # Compressed bodies are stored decoded, so the filters below can see into them.
  c.default_cassette_options = {
    record: ENV['RECORD_VCR'] ? :new_episodes : :none,
    match_requests_on: %i[method adyen_route],
    decode_compressed_response: true
  }

  # Adyen ids in the path (sessions, PSP references, merchant accounts,
  # webhooks) differ between the test account a recording used and the
  # placeholders a replay passes, so they are matched as one segment.
  c.register_request_matcher :adyen_route do |recorded, replayed|
    route = lambda do |request|
      URI(request.uri).path.gsub(%r{/(?=[A-Za-z0-9_-]*\d)[A-Za-z0-9_-]{10,}(?=/|\z)}, '/:id')
    end
    route.call(recorded) == route.call(replayed)
  end

  c.filter_sensitive_data('<ADYEN_API_KEY>') { ENV.fetch('ADYEN_API_KEY', nil) }
  # Recorded as a placeholder and replayed as the factory's merchant account,
  # since it travels in Management API paths the matcher compares.
  c.filter_sensitive_data('<ADYEN_MERCHANT_ACCOUNT>') { ENV.fetch('ADYEN_MERCHANT_ACCOUNT', 'SpreeTestECOM') }
  c.filter_sensitive_data('<ADYEN_LIMITED_API_KEY>') { ENV.fetch('ADYEN_LIMITED_API_KEY', nil) }

  c.before_record do |interaction|
    # The API key travels in its own header, which the filters above only
    # catch when it is set in the environment.
    interaction.request.headers['X-Api-Key'] = ['<FILTERED>'] if interaction.request.headers.key?('X-Api-Key')
    # A session result is read with GET /sessions/{id}?sessionResult=..., in the URL.
    interaction.request.uri = interaction.request.uri.sub(/([?&]sessionResult=)[^&]+/, '\\1<FILTERED>')

    [interaction.request, interaction.response].each do |message|
      next if message.body.blank?

      message.body = message.body.
                     gsub(/"(clientKey|hmacKey|sessionData|sessionResult|redirectResult)"\s*:\s*"[^"]*"/, '"\1":"<FILTERED>"')
    end
  end
end
