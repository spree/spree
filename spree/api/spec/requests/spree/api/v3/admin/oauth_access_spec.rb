require 'spec_helper'

# An OAuth token reaches the whole Admin API, not just the MCP endpoint, so an
# app can do the work a merchant connected it for — fetch the export it just
# made, read an order, update a product.
RSpec.describe 'Admin API OAuth access', type: :request do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:application) do
    store.oauth_applications.create!(name: "App #{SecureRandom.hex(4)}",
                                     redirect_uri: 'https://example.com/callback',
                                     confidential: false)
  end

  def token_for(scopes, resource:)
    Spree::OauthAccessToken.create!(
      application: application, resource_owner: admin, scopes: scopes,
      expires_in: 3600, resource: "http://www.example.com#{resource}"
    ).plaintext_token
  end

  def get_with(token, path)
    get path, headers: { 'Authorization' => "Bearer #{token}" }
  end

  describe 'a token issued for the Admin API' do
    let(:token) { token_for('read_products', resource: '/api/v3/admin') }

    it 'is accepted' do
      get_with(token, '/api/v3/admin/products')

      expect(response).to have_http_status(:ok)
    end

    # The whole point of a grant: it subtracts from what the approver holds.
    # This regressed once because the module defining the narrowing hook was
    # included *after* the one overriding it, so the override was dead code
    # and a `read_products` token could create a product.
    it 'cannot reach a resource the merchant did not grant' do
      get_with(token, '/api/v3/admin/orders')

      expect(response).to have_http_status(:forbidden)
    end

    it 'cannot write where it was granted only read' do
      post '/api/v3/admin/products',
           params: { name: 'Should not exist' },
           headers: { 'Authorization' => "Bearer #{token}" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  # RFC 8707: a token names the resources it may be used against. A client
  # that asked for one endpoint must not receive a credential good across the
  # rest of the API.
  describe 'a token issued for another resource' do
    it 'is refused' do
      get_with(token_for('read_products', resource: '/api/v3/admin/mcp'),
               '/api/v3/admin/products')

      expect(response).to have_http_status(:unauthorized)
    end

    it 'is refused when it names no resource at all' do
      token = Spree::OauthAccessToken.create!(
        application: application, resource_owner: admin,
        scopes: 'read_products', expires_in: 3600
      ).plaintext_token

      get_with(token, '/api/v3/admin/products')

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # The client is registered for one store and consented to on that store, so
  # the token names the tenancy. Reading the header instead would let a client
  # name another merchant's store on a grant that never covered it.
  describe 'the store a token acts on' do
    it 'comes from the application, not the request header' do
      other = create(:store)
      token = token_for('read_products', resource: '/api/v3/admin')

      get '/api/v3/admin/products',
          headers: { 'Authorization' => "Bearer #{token}",
                     'X-Spree-Store-Id' => other.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(assigns(:current_store) || controller.send(:current_store)).to eq(store)
    end
  end
end
