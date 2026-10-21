require 'spec_helper'

# The shopper's endpoint and its discovery profile, from the request down.
RSpec.describe 'Storefront MCP endpoint', type: :request do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :publishable, store: store) }
  let!(:product) { create(:product, store: store, status: 'active', name: 'Linen Shirt') }

  def post_rpc(method, params = nil, path: "/api/v3/store/mcp?key=#{api_key.token}", headers: {})
    message = { jsonrpc: '2.0', id: 1, method: method }
    message[:params] = params if params

    post path, params: message.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }.merge(headers)
    JSON.parse(response.body)
  end

  describe 'authentication' do
    it 'takes the publishable key in the URL, since a client may be given nothing else' do
      post_rpc('tools/list')

      expect(response).to have_http_status(:ok)
    end

    it 'takes it in the Store API header too' do
      post_rpc('tools/list', path: '/api/v3/store/mcp', headers: { 'X-Spree-API-Key' => api_key.token })

      expect(response).to have_http_status(:ok)
    end

    it 'says how to fix a missing key, as a JSON-RPC error the client will show' do
      body = post_rpc('tools/list', path: '/api/v3/store/mcp')

      expect(response).to have_http_status(:unauthorized)
      expect(body.dig('error', 'message')).to include('?key=pk_')
    end

    it 'refuses a secret key' do
      secret = create(:api_key, :secret, store: store, scopes: ['read_all'])

      post_rpc('tools/list', path: "/api/v3/store/mcp?key=#{secret.plaintext_token}")

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'tools/list' do
    let(:tools) { post_rpc('tools/list').dig('result', 'tools') }

    it 'offers the shopping tools and nothing from the back office' do
      names = tools.map { |tool| tool['name'] }

      expect(names).to include('search_catalog', 'create_cart', 'create_checkout', 'get_order')
      expect(names).not_to include('search_resources', 'orders_cancel')
    end

    # A shopper's agent should not have to confirm adding to a cart the way
    # it confirms cancelling one.
    it 'marks filling a cart as a write that is not destructive' do
      create_cart = tools.find { |tool| tool['name'] == 'create_cart' }
      cancel_cart = tools.find { |tool| tool['name'] == 'cancel_cart' }

      expect(create_cart['annotations']).to include('readOnlyHint' => false, 'destructiveHint' => false)
      expect(cancel_cart['annotations']).to include('destructiveHint' => true)
    end
  end

  describe 'tools/call' do
    it 'answers with the UCP payload as structured content' do
      body = post_rpc('tools/call', { name: 'search_catalog',
                                      arguments: { meta: { 'ucp-agent' => { profile: 'https://agent.example/profile' } },
                                                   catalog: { query: '' } } })

      result = body['result']
      expect(result['isError']).to be_falsey
      expect(result.dig('structuredContent', 'ucp', 'version')).to eq('2026-08-25')
      expect(result.dig('structuredContent', 'products').map { |entry| entry['id'] }).to include(product.prefixed_id)
    end
  end

  describe 'GET /api/v3/store/ucp_profile' do
    it 'advertises this endpoint, carrying the key, and the capabilities it implements' do
      get "/api/v3/store/ucp_profile?key=#{api_key.token}"

      profile = JSON.parse(response.body)['ucp']
      binding = profile.dig('services', 'dev.ucp.shopping').first

      expect(profile['version']).to eq('2026-08-25')
      expect(binding).to include('transport' => 'mcp', 'endpoint' => "http://www.example.com/api/v3/store/mcp?key=#{api_key.token}")
      expect(profile['capabilities'].keys).to include('dev.ucp.shopping.checkout', 'dev.ucp.shopping.catalog.search')
      expect(profile['payment_handlers']).to eq({})
    end
  end
end
