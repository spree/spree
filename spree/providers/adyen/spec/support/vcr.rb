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
#   ADYEN_CAPTURED_PSP_REFERENCE  a payment already captured in full (capture_refused, cancel_refused, refund_*)
#   ADYEN_PAID_SESSION_ID / ADYEN_PAID_SESSION_RESULT            a session paid by card through Drop-in
#   ADYEN_SAVED_CARD_SESSION_ID / ADYEN_SAVED_CARD_SESSION_RESULT a session paid with "Save for my next payment" ticked
#   ADYEN_PENDING_SESSION_ID / ADYEN_PENDING_SESSION_RESULT      a session paid by a method that pends
#   ADYEN_REFUSED_SESSION_ID / ADYEN_REFUSED_SESSION_RESULT      a session refused until Adyen stopped it
#   ADYEN_EXPIRED_SESSION_ID / ADYEN_EXPIRED_SESSION_RESULT      a session left past its expiry
#   ADYEN_ACTIVE_SESSION_ID / ADYEN_ACTIVE_SESSION_RESULT        a session not paid
#   ADYEN_PAYABLE_SESSION_ID / ADYEN_PAYABLE_SESSION_DATA        a session already made payable
#   ADYEN_AUTHORISED_REDIRECT_RESULT / ADYEN_REFUSED_REDIRECT_RESULT  iDEAL test redirects, completed and cancelled
#   ADYEN_SETUP_SESSION_ID / ADYEN_SETUP_SESSION_RESULT          a setup session completed through Drop-in
#   ADYEN_LEGACY_WEBHOOK_ID   a webhook on .../adyen/webhooks (configure_legacy_webhook_url)
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
  c.filter_sensitive_data('<ADYEN_LIMITED_API_KEY>') { ENV.fetch('ADYEN_LIMITED_API_KEY', nil) }

  c.before_record do |interaction|
    # The API key travels in its own header, which the filters above only
    # catch when it is set in the environment.
    interaction.request.headers['X-Api-Key'] = ['<FILTERED>'] if interaction.request.headers.key?('X-Api-Key')

    [interaction.request, interaction.response].each do |message|
      next if message.body.blank?

      message.body = message.body.
                     gsub(/"(clientKey|hmacKey|sessionData|sessionResult|redirectResult)"\s*:\s*"[^"]*"/, '"\1":"<FILTERED>"')
    end
  end
end
