require 'spec_helper'

# The two discovery documents are the whole of a consumer client's first
# impression: it reads them before it has any credential, and a missing or
# inconsistent field makes it stop rather than ask. Each required field gets
# its own assertion for that reason.
RSpec.describe 'OAuth discovery', type: :request do
  let(:store) { @default_store }

  before { Spree::Api::Oauth.register_resource(:mcp, '/api/v3/admin/mcp') }

  describe 'GET /.well-known/oauth-authorization-server' do
    subject(:document) do
      get '/.well-known/oauth-authorization-server'
      JSON.parse(response.body)
    end

    it 'names every endpoint a client needs to run the code flow' do
      expect(document['authorization_endpoint']).to be_present
      expect(document['token_endpoint']).to be_present
    end

    # A client verifies PKCE support before it will proceed, so an absent or
    # `plain`-carrying list is enough for it to refuse the connection.
    it 'offers S256 and nothing weaker' do
      expect(document['code_challenge_methods_supported']).to eq(['S256'])
    end

    it 'advertises only the authorization-code family' do
      expect(document['grant_types_supported']).to include('authorization_code')
      expect(document['grant_types_supported']).not_to include('password', 'client_credentials')
    end

    it 'advertises audience-restricted tokens' do
      expect(document['resource_indicators_supported']).to be(true)
    end

    it 'offers Spree permission keys as scopes' do
      expect(document['scopes_supported']).to include('read_products', 'write_orders')
    end
  end

  describe 'GET /api/v3/oauth/protected-resource/:resource_key' do
    it 'echoes the resource identifier a token must be bound to' do
      get '/api/v3/oauth/protected-resource/mcp'

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      # Built from the request rather than from anything configured, so a
      # deployment behind a proxy or reachable at several hostnames still
      # hands a client an identifier matching the URL it used.
      expect(body['resource']).to end_with('/api/v3/admin/mcp')
      expect(URI.parse(body['resource']).origin).to eq(URI.parse(response.request.base_url).origin)
      expect(body['authorization_servers']).to be_present
      expect(body['bearer_methods_supported']).to eq(['header'])
    end

    it 'is not found for a resource nothing registered' do
      get '/api/v3/oauth/protected-resource/nothing_here'

      expect(response).to have_http_status(:not_found)
    end
  end

  # The client id names the store, not the hostname. An installation serving
  # several stores from one API origin would otherwise send every consent to
  # whichever store that host resolves as, and a merchant would approve on
  # the wrong one.
  describe 'GET /oauth/authorize for another store\'s client' do
    it 'sends the browser to the store the client belongs to' do
      other = create(:store, code: "other-#{SecureRandom.hex(4)}")
      application = other.oauth_applications.create!(
        name: 'Other store client', redirect_uri: 'https://example.test/cb', confidential: false
      )

      get '/oauth/authorize', params: {
        client_id: application.uid, redirect_uri: 'https://example.test/cb', response_type: 'code'
      }

      expect(response).to have_http_status(:found)
      expect(response.location).to include(other.prefixed_id)
      expect(response.location).not_to include(store.prefixed_id)
    end
  end

  # The endpoint exists so the metadata document can name it; it renders
  # nothing itself and hands the browser to the dashboard.
  describe 'GET /oauth/authorize' do
    it 'sends the browser to the dashboard with the request intact' do
      get '/oauth/authorize', params: {
        client_id: 'abc', redirect_uri: 'https://example.test/cb',
        response_type: 'code', scope: 'read_products', state: 'xyz'
      }

      expect(response).to have_http_status(:found)
      expect(response.location).to include('/oauth/authorize')
      expect(response.location).to include('state=xyz', 'client_id=abc')
    end
  end
end
