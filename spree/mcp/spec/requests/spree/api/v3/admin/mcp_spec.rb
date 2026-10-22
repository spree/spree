require 'spec_helper'
require 'benchmark'

# The endpoint, from the header down. A request spec rather than a controller
# spec because the unit under test is the whole request: the credential, the
# store it selects, and a JSON-RPC body that never touches a view.
RSpec.describe 'Admin MCP endpoint', type: :request do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:scopes) { 'write_all' }
  let(:application) do
    store.oauth_applications.create!(
      name: 'Probe', redirect_uri: 'https://example.test/callback', confidential: false
    )
  end
  # What consent mints for an MCP client: the MCP endpoint and the Admin API,
  # because a tool call dispatches to an Admin API operation as the same
  # grant. A token naming only one surface is exercised below.
  let(:resource) { Spree::Api::Oauth.resource_identifier(:admin) }
  let(:token) { oauth_token(scopes: scopes) }

  before { Spree::Api::Oauth.register_resource(:mcp, '/api/v3/admin/mcp') }

  def oauth_token(scopes:, audience: resource, owner: admin, application: self.application)
    Spree::OauthAccessToken.create!(
      application: application, resource_owner: owner,
      scopes: Array(scopes).join(' '), expires_in: 2.hours.to_i, resource: audience
    ).plaintext_token
  end

  def post_rpc(method, params = nil, headers: {}, id: 1)
    message = { jsonrpc: '2.0', id: id, method: method }
    message[:params] = params if params

    post '/api/v3/admin/mcp', params: message.to_json,
                              headers: { 'CONTENT_TYPE' => 'application/json' }.merge(headers)
    JSON.parse(response.body)
  end

  def post_with_token(raw_token, method = 'tools/list', params = nil)
    post_rpc(method, params, headers: { 'Authorization' => "Bearer #{raw_token}" })
  end

  # An agent acts for a person, so the only credential this endpoint takes is
  # that person's grant. A secret key authenticates the rest of the Admin API
  # and the CLI; here it would be a standing credential with nobody behind
  # it, naming neither who approved the agent nor what they allowed.
  describe 'authentication' do
    it 'accepts an OAuth token' do
      body = post_with_token(token)

      expect(response).to have_http_status(:ok)
      expect(body['result']['tools']).to be_present
    end

    it 'refuses a secret API key in the Admin API header' do
      api_key = create(:api_key, :secret, store: store, scopes: ['write_all'])

      post_rpc('tools/list', headers: { 'X-Spree-API-Key' => api_key.plaintext_token })

      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses a secret API key as a bearer token' do
      api_key = create(:api_key, :secret, store: store, scopes: ['write_all'])

      post_with_token(api_key.plaintext_token)

      expect(response).to have_http_status(:unauthorized)
    end

    # The Admin API tries a secret key before a bearer token, so a key sent
    # beside the grant would have authenticated every call a tool makes — in
    # the key's store and under its scopes — while the tool list was built
    # from the grant. Two credentials never act at once.
    it 'refuses a request carrying a secret key beside the grant' do
      api_key = create(:api_key, :secret, store: store, scopes: ['write_all'])

      post_rpc('tools/list', headers: { 'Authorization' => "Bearer #{token}",
                                        'X-Spree-API-Key' => api_key.plaintext_token })

      expect(response).to have_http_status(:unauthorized)
    end

    # Parsing the bearer header must not backtrack: this header arrives
    # unauthenticated, so a pathological value is free to send.
    it 'parses a bearer header of many spaces without stalling' do
      elapsed = Benchmark.realtime do
        post_rpc('tools/list', headers: { 'Authorization' => "Bearer #{' ' * 50_000}x" })
      end

      expect(response).to have_http_status(:unauthorized)
      expect(elapsed).to be < 1.0
    end

    it 'accepts a bearer token with extra whitespace' do
      post_rpc('tools/list', headers: { 'Authorization' => "Bearer    #{token}" })

      expect(response).to have_http_status(:ok)
    end

    # The message is what a person reads when their client is misconfigured,
    # so it has to say what to do rather than only that something failed.
    it 'refuses an anonymous request, pointing at signing in' do
      body = post_rpc('tools/list')

      expect(response).to have_http_status(:unauthorized)
      expect(body.dig('error', 'message')).to include('Sign in')
    end

    # This is a machine surface: a browser session belongs to the dashboard
    # assistant, which reads the same registry with the admin's own ability.
    it 'refuses a JWT' do
      post_rpc('tools/list', headers: { 'Authorization' => 'Bearer eyJhbGciOiJIUzI1NiJ9.e30.signature' })

      expect(response).to have_http_status(:unauthorized)
    end

    # An unauthenticated request has to tell a consumer client where to sign
    # in, otherwise there is nothing for it to act on: hosted connectors read
    # this header and start the flow themselves.
    it 'challenges an anonymous request with the discovery document' do
      post_rpc('tools/list')

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['WWW-Authenticate']).to include(
        'resource_metadata="', '/api/v3/oauth/protected-resource/admin'
      )
    end

    it 'names the same scheme and host in the realm and the metadata URL' do
      post_rpc('tools/list')

      challenge = response.headers['WWW-Authenticate']
      realm = challenge[/realm="([^"]+)"/, 1]
      metadata = challenge[/resource_metadata="([^"]+)"/, 1]

      expect(URI.parse(metadata).origin).to eq(URI.parse(realm).origin)
    end
  end

  # A merchant grants part of their own authority to a client. Two properties
  # carry the whole arrangement: the grant can only narrow what the user may
  # do, and a token issued for some other resource cannot be replayed here.
  describe 'the grant' do
    it 'authenticates a token and acts as its owner' do
      body = post_with_token(oauth_token(scopes: 'read_products'))

      expect(response).to have_http_status(:ok)
      expect(body['result']['tools']).to be_present
    end

    it 'narrows the catalog to what the merchant consented to' do
      granted = post_with_token(oauth_token(scopes: 'read_products'))['result']['tools']
      everything = post_with_token(oauth_token(scopes: 'write_all'))['result']['tools']

      expect(granted.size).to be < everything.size
      expect(granted.map { |tool| tool['name'] }).not_to include('orders_cancel')
    end

    it 'refuses a token issued for another resource' do
      # Built from the identifier, not from the granted pair: that is two
      # space-separated indicators now, so appending to it would leave the
      # first one valid and the token would rightly be accepted.
      post_with_token(oauth_token(scopes: 'read_products',
                                  audience: "#{Spree::Api::Oauth.resource_identifier(:mcp)}/other"))

      expect(response).to have_http_status(:unauthorized)
    end

    # Stricter than Doorkeeper's own comparison, which treats two blanks as a
    # match: a token that names no audience cannot be shown to have been
    # issued for this endpoint.
    it 'refuses a token with no audience at all' do
      post_with_token(oauth_token(scopes: 'read_products', audience: nil))

      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses a revoked token' do
      raw = oauth_token(scopes: 'read_products')
      Spree::OauthAccessToken.by_token(raw).update!(revoked_at: Time.current)

      post_with_token(raw)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses an expired token' do
      raw = oauth_token(scopes: 'read_products')
      Spree::OauthAccessToken.by_token(raw).update!(created_at: 3.hours.ago)

      post_with_token(raw)

      expect(response).to have_http_status(:unauthorized)
    end

    # The grant outlives the role it was approved under, so membership is
    # asked on every request rather than trusted from consent.
    it 'refuses a token whose owner no longer holds a role on the store' do
      raw = oauth_token(scopes: 'read_products')
      admin.role_users.destroy_all

      post_with_token(raw)

      expect(response).to have_http_status(:unauthorized)
    end

    # An MCP client sends a URL and a bearer token and nothing else, so the
    # token has to select its own store — otherwise the endpoint would serve
    # the default store whatever the grant said. The owner holds a role on
    # that store, as anyone who could have approved the grant does.
    it 'serves the store its application belongs to, with no store header' do
      other = create(:store, code: "other-#{SecureRandom.hex(4)}")
      create(:role_user, user: admin, role: create(:role, resource: other))
      application = other.oauth_applications.create!(
        name: 'Other store client', redirect_uri: 'https://example.test/cb', confidential: false
      )
      raw = Spree::OauthAccessToken.create!(
        application: application, resource_owner: admin, scopes: 'read_products',
        expires_in: 2.hours.to_i, resource: Spree::Api::Oauth.resource_identifier(:admin)
      ).plaintext_token

      body = post_with_token(raw)

      expect(response).to have_http_status(:ok)
      expect(body['result']['tools']).to be_present
    end
  end

  # Everything else here hands the controller a token built in Ruby, which
  # proved nothing about the audience a real grant carries: consent is what
  # sets it, and it was setting nothing. This walks the sequence a client
  # actually performs.
  describe 'a client connecting for real' do
    def connect(scope: 'read_products')
      verifier = 'v' * 64
      challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
      jwt = Spree::Api::V3::TestingSupport.generate_jwt(
        admin, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN
      )

      post '/api/v3/admin/oauth/authorize',
           params: { client_id: application.uid, redirect_uri: application.redirect_uri,
                     response_type: 'code', scope: scope,
                     code_challenge: challenge, code_challenge_method: 'S256' },
           headers: { 'Authorization' => "Bearer #{jwt}" }

      redirect = JSON.parse(response.body)['redirect_uri']
      code = Rack::Utils.parse_query(URI.parse(redirect).query)['code']

      post '/oauth/token',
           params: { grant_type: 'authorization_code', code: code, client_id: application.uid,
                     redirect_uri: application.redirect_uri, code_verifier: verifier }

      JSON.parse(response.body)['access_token']
    end

    it 'calls a tool with the token consent issued' do
      raw = connect

      body = post_rpc('tools/call',
                      { name: 'search_resources', arguments: { 'resource' => 'products' } },
                      headers: { 'Authorization' => "Bearer #{raw}" })

      expect(response).to have_http_status(:ok)
      expect(body.dig('result', 'isError')).to be(false)
    end

    # The call the tool makes on the caller's behalf runs as the same token,
    # so a grant bound to the wrong audience leaves every tool answering
    # "authentication required" while the endpoint itself looks healthy.
    it 'reaches the Admin API with that same token' do
      raw = connect

      get '/api/v3/admin/products', headers: { 'Authorization' => "Bearer #{raw}" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'tenancy' do
    it 'serves the key\'s own store when the header agrees' do
      body = post_rpc('tools/call',
                      { name: 'search_resources', arguments: { 'resource' => 'products' } },
                      headers: { 'Authorization' => "Bearer #{token}", 'X-Spree-Store-Id' => store.prefixed_id })

      expect(response).to have_http_status(:ok)
      expect(body.dig('result', 'isError')).to be(false)
    end

    # The grant selects the store, through the application it was issued
    # for. A header naming another store cannot widen that: the audience the
    # token carries is the whole answer, so the header is simply not
    # consulted.
    it 'ignores a header naming another store' do
      other_store = create(:store, code: "other-#{SecureRandom.hex(4)}")
      other_product = create(:product, store: other_store)

      body = post_rpc('tools/call',
                      { name: 'get_resource',
                        arguments: { 'resource' => 'products', 'id' => other_product.prefixed_id } },
                      headers: { 'Authorization' => "Bearer #{token}",
                                 'X-Spree-Store-Id' => other_store.prefixed_id })

      expect(body.dig('result', 'isError')).to be(true)
    end

    it 'does not find another store\'s record' do
      other_product = create(:product, store: create(:store, code: "other-#{SecureRandom.hex(4)}"))

      body = post_rpc('tools/call',
                      { name: 'get_resource', arguments: { 'resource' => 'products', 'id' => other_product.prefixed_id } },
                      headers: { 'Authorization' => "Bearer #{token}" })

      expect(body.dig('result', 'isError')).to be(true)
    end
  end

  describe 'running a workflow end to end' do
    let(:order) { create(:completed_order_with_totals, store: store) }
    let(:fulfillment) { order.shipments.first }

    # A write used to answer with its summary line alone — "Orders cancel
    # R1002" — so a model had to fetch the record again to report what
    # changed, and an assistant reading only the text could not confirm the
    # write at all.
    it 'answers a write with the record it changed' do
      body = post_rpc('tools/call',
                      { name: 'orders_cancel', arguments: { 'order' => order.prefixed_id } },
                      headers: { 'Authorization' => "Bearer #{token}" })

      expect(body.dig('result', 'isError')).to be(false)
      expect(body.dig('result', 'structuredContent', 'record', 'status')).to eq('canceled')
      expect(body.dig('result', 'content', 0, 'text')).to include('canceled')
    end

    it 'marks a fulfillment delivered through the real workflow' do
      fulfillment.update!(status: 'fulfilled')

      body = post_rpc('tools/call',
                      { name: 'fulfillments_mark_delivered', arguments: { 'fulfillment' => fulfillment.prefixed_id } },
                      headers: { 'Authorization' => "Bearer #{token}" })

      expect(body.dig('result', 'isError')).to be(false)
      expect(fulfillment.reload.status).to eq('delivered')
    end

    # The grant names a person, so that is who the timeline records — an
    # audit later shows which admin's agent did it, not an anonymous
    # credential.
    it 'records the approving admin as the actor when it cancels an order' do
      reason = create(:order_cancellation_reason, store: store)

      body = post_rpc('tools/call',
                      { name: 'orders_cancel',
                        arguments: { 'order' => order.prefixed_id, 'reason' => reason.prefixed_id } },
                      headers: { 'Authorization' => "Bearer #{token}" })

      expect(body.dig('result', 'isError')).to be(false)
      expect(order.reload.status).to eq('canceled')
      expect(order.canceler).to eq(admin)
    end

    it 'carries the workflow\'s own refusal back as a tool error' do
      body = post_rpc('tools/call',
                      { name: 'orders_cancel', arguments: { 'order' => 'order_nope' } },
                      headers: { 'Authorization' => "Bearer #{token}" })

      expect(body.dig('result', 'isError')).to be(true)
      expect(body.dig('result', 'content').first['text']).to include('order')
    end
  end

  describe 'scope filtering' do
    let(:scopes) { ['read_orders'] }

    it 'offers only what the key\'s scopes permit' do
      body = post_rpc('tools/list', headers: { 'Authorization' => "Bearer #{token}" })
      names = body.dig('result', 'tools').map { |tool| tool['name'] }

      expect(names).to include('search_resources')
      expect(names).not_to include('orders_cancel')
    end
  end
end
