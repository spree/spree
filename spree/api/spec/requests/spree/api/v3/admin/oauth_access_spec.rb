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

    # The narrowing lives in the scope gate, so an endpoint that skips that
    # gate and guards itself has to ask about the caller rather than about a
    # secret key — a token resolves as a staff user and carries none, which
    # once let a read-only grant rewrite a product's translations.
    it 'cannot write through an endpoint that guards itself' do
      configure_supported_locales(store, %w[en de])
      product = create(:product, store: store, name: 'Espresso Machine')

      post '/api/v3/admin/translations/batch',
           params: { translations: [{ resource_type: 'product', resource_id: product.prefixed_id,
                                      translations: { de: { name: 'Rewritten' } } }] }.to_json,
           headers: { 'Authorization' => "Bearer #{token}", 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:forbidden)
      expect(product.reload.name).to eq('Espresso Machine')
    end

    # Several resources are guarded by a permission not named after them, so
    # a name derived from the resource type fell outside the catalog and went
    # unchecked — a read-only grant could rewrite an option type's or a
    # policy's translations.
    it 'cannot write a resource whose permission is not named after it' do
      configure_supported_locales(store, %w[en de])
      option_type = create(:option_type, label: 'Size')

      post '/api/v3/admin/translations/batch',
           params: { translations: [{ resource_type: 'option_type', resource_id: option_type.prefixed_id,
                                      values: { de: { label: 'Rewritten' } } }] }.to_json,
           headers: { 'Authorization' => "Bearer #{token}", 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:forbidden)
      expect(json_response['error']['details']['required_scopes']).to eq(['write_products'])
    end

    # A list filtered only for secret keys told an agent which kinds of
    # export exist — including customers and gift cards. An import row goes
    # further and carries a real line from the uploaded file.
    it 'lists only the kinds of export the merchant granted' do
      Spree::Exports::Products.create!(store: store, user: admin)
      Spree::Exports::Customers.create!(store: store, user: admin)

      get_with(token, '/api/v3/admin/exports')
      types = json_response['data'].map { |row| row['type'] }.uniq

      expect(types).to include('products')
      expect(types).not_to include('customers')
    end

    it 'lists only the kinds of import the merchant granted' do
      Spree::Imports::Products.create!(store: store, user: admin)
      Spree::Imports::Customers.create!(store: store, user: admin)

      get_with(token_for('write_products', resource: '/api/v3/admin'), '/api/v3/admin/imports')
      types = json_response['data'].map { |row| row['type'] }.uniq

      expect(types).to include('products')
      expect(types).not_to include('customers')
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
