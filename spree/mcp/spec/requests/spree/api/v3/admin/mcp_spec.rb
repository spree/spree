require 'spec_helper'
require 'benchmark'

# The endpoint, from the header down. A request spec rather than a controller
# spec because the unit under test is the whole request: the credential, the
# store it selects, and a JSON-RPC body that never touches a view.
RSpec.describe 'Admin MCP endpoint', type: :request do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: scopes) }
  let(:scopes) { ['write_all'] }
  let(:token) { api_key.plaintext_token }

  def post_rpc(method, params = nil, headers: {}, id: 1)
    message = { jsonrpc: '2.0', id: id, method: method }
    message[:params] = params if params

    post '/api/v3/admin/mcp', params: message.to_json,
                              headers: { 'CONTENT_TYPE' => 'application/json' }.merge(headers)
    JSON.parse(response.body)
  end

  describe 'authentication' do
    it 'accepts the Admin API header' do
      body = post_rpc('tools/list', headers: { 'X-Spree-API-Key' => token })

      expect(response).to have_http_status(:ok)
      expect(body['result']['tools']).to be_present
    end

    # Several MCP clients offer a bearer-token field and no custom header, so
    # the same key is accepted there.
    it 'accepts the key as a bearer token' do
      body = post_rpc('tools/list', headers: { 'Authorization' => "Bearer #{token}" })

      expect(response).to have_http_status(:ok)
      expect(body['result']['tools']).to be_present
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

    it 'accepts a bearer key with extra whitespace' do
      post_rpc('tools/list', headers: { 'Authorization' => "Bearer    #{token}" })

      expect(response).to have_http_status(:ok)
    end

    it 'refuses a request with no key, naming the header to set' do
      body = post_rpc('tools/list')

      expect(response).to have_http_status(:unauthorized)
      expect(body.dig('error', 'message')).to include('X-Spree-API-Key')
    end

    it 'refuses a publishable key' do
      publishable = create(:api_key, :publishable, store: store)

      post_rpc('tools/list', headers: { 'X-Spree-API-Key' => publishable.token })

      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses a revoked key' do
      revoked = create(:api_key, :secret, store: store)
      plaintext = revoked.plaintext_token
      revoked.revoke!

      post_rpc('tools/list', headers: { 'X-Spree-API-Key' => plaintext })

      expect(response).to have_http_status(:unauthorized)
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
        'resource_metadata="', '/api/v3/oauth/protected-resource/mcp'
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
  describe 'OAuth authentication' do
    let(:admin) { create(:admin_user) }
    let(:resource) { Spree::Api::Oauth.resource_identifier(:mcp) }
    let(:application) do
      store.oauth_applications.create!(
        name: 'Probe', redirect_uri: 'https://example.test/callback', confidential: false
      )
    end

    def oauth_token(scopes:, audience: resource, owner: admin)
      Spree::OauthAccessToken.create!(
        application: application, resource_owner: owner,
        scopes: Array(scopes).join(' '), expires_in: 2.hours.to_i, resource: audience
      ).token
    end

    def post_with_token(raw_token, method = 'tools/list')
      post_rpc(method, headers: { 'Authorization' => "Bearer #{raw_token}" })
    end

    it 'authenticates a token and acts as its owner' do
      body = post_with_token(oauth_token(scopes: 'read_products'))

      expect(response).to have_http_status(:ok)
      expect(body['result']['tools']).to be_present
    end

    it 'narrows the catalog to what the merchant consented to' do
      granted = post_with_token(oauth_token(scopes: 'read_products'))['result']['tools']
      key_offers = post_rpc('tools/list', headers: { 'X-Spree-API-Key' => token })['result']['tools']

      expect(granted.size).to be < key_offers.size
      expect(granted.map { |tool| tool['name'] }).not_to include('orders_cancel')
    end

    it 'refuses a token issued for another resource' do
      post_with_token(oauth_token(scopes: 'read_products', audience: "#{resource}/other"))

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

    # An MCP client sends a URL and a bearer token and nothing else, so the
    # token has to select its own store — otherwise the endpoint would serve
    # the default store whatever the grant said.
    it 'serves the store its application belongs to, with no store header' do
      other = create(:store, code: "other-#{SecureRandom.hex(4)}")
      application = other.oauth_applications.create!(
        name: 'Other store client', redirect_uri: 'https://example.test/cb', confidential: false
      )
      raw = Spree::OauthAccessToken.create!(
        application: application, resource_owner: admin, scopes: 'read_products',
        expires_in: 2.hours.to_i, resource: Spree::Api::Oauth.resource_identifier(:mcp)
      ).token

      body = post_with_token(raw)

      expect(response).to have_http_status(:ok)
      expect(body['result']['tools']).to be_present
    end
  end

  describe 'tenancy' do
    it 'serves the key\'s own store when the header agrees' do
      body = post_rpc('tools/call',
                      { name: 'search_resources', arguments: { 'resource' => 'products' } },
                      headers: { 'X-Spree-API-Key' => token, 'X-Spree-Store-Id' => store.prefixed_id })

      expect(response).to have_http_status(:ok)
      expect(body.dig('result', 'isError')).to be(false)
    end

    # The key selects the store; a header naming a different one is refused
    # outright rather than quietly served the key's own store.
    it 'refuses a header naming another store' do
      other_store = create(:store, code: "other-#{SecureRandom.hex(4)}")

      post_rpc('tools/call',
               { name: 'search_resources', arguments: { 'resource' => 'products' } },
               headers: { 'X-Spree-API-Key' => token, 'X-Spree-Store-Id' => other_store.prefixed_id })

      expect(response).to have_http_status(:forbidden)
    end

    it 'does not find another store\'s record' do
      other_product = create(:product, store: create(:store, code: "other-#{SecureRandom.hex(4)}"))

      body = post_rpc('tools/call',
                      { name: 'get_resource', arguments: { 'resource' => 'products', 'id' => other_product.prefixed_id } },
                      headers: { 'X-Spree-API-Key' => token })

      expect(body.dig('result', 'isError')).to be(true)
    end
  end

  describe 'running a workflow end to end' do
    let(:order) { create(:completed_order_with_totals, store: store) }
    let(:fulfillment) { order.shipments.first }

    it 'marks a fulfillment delivered through the real workflow' do
      fulfillment.update!(status: 'fulfilled')

      body = post_rpc('tools/call',
                      { name: 'fulfillments_mark_delivered', arguments: { 'fulfillment' => fulfillment.prefixed_id } },
                      headers: { 'X-Spree-API-Key' => token })

      expect(body.dig('result', 'isError')).to be(false)
      expect(fulfillment.reload.status).to eq('delivered')
    end

    it 'records the API key as the actor when it cancels an order' do
      reason = create(:order_cancellation_reason, store: store)

      body = post_rpc('tools/call',
                      { name: 'orders_cancel',
                        arguments: { 'order' => order.prefixed_id, 'reason' => reason.prefixed_id } },
                      headers: { 'X-Spree-API-Key' => token })

      expect(body.dig('result', 'isError')).to be(false)
      expect(order.reload.status).to eq('canceled')
      expect(order.canceler).to eq(api_key)
    end

    it 'carries the workflow\'s own refusal back as a tool error' do
      body = post_rpc('tools/call',
                      { name: 'orders_cancel', arguments: { 'order' => 'order_nope' } },
                      headers: { 'X-Spree-API-Key' => token })

      expect(body.dig('result', 'isError')).to be(true)
      expect(body.dig('result', 'content').first['text']).to include('order')
    end
  end

  describe 'scope filtering' do
    let(:scopes) { ['read_orders'] }

    it 'offers only what the key\'s scopes permit' do
      body = post_rpc('tools/list', headers: { 'X-Spree-API-Key' => token })
      names = body.dig('result', 'tools').map { |tool| tool['name'] }

      expect(names).to include('search_resources')
      expect(names).not_to include('orders_cancel')
    end
  end
end
