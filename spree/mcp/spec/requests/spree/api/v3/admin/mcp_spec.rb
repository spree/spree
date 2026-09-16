require 'spec_helper'

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
