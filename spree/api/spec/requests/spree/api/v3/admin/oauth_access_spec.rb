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

    # Reporting gates each dimension on the scope for the data it exposes,
    # so a grant for reports alone must not reach customer names, emails and
    # spend by grouping on them.
    it 'cannot report on a dimension outside its scopes' do
      post '/api/v3/admin/reporting/query',
           params: { metrics: ['net_sales'], dimensions: ['customer'] }.to_json,
           headers: { 'Authorization' => "Bearer #{token_for('read_reports', resource: '/api/v3/admin')}",
                      'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig('error', 'message')).to include('read_customers')
    end

    # And the vocabulary it is offered matches, so it is not told to ask for
    # something it would be refused.
    it 'is not offered a dimension it may not use' do
      get '/api/v3/admin/reporting/schema',
          headers: { 'Authorization' => "Bearer #{token_for('read_reports', resource: '/api/v3/admin')}" }

      names = JSON.parse(response.body)['dimensions'].map { |dimension| dimension['name'] }

      expect(names).to include('completed_at')
      expect(names).not_to include('customer')
    end

    # The widest version of the same fault: the consent endpoint mints
    # grants, so an agent that could reach it with its owner's whole role
    # could approve itself anything that role can do — and a grant is a
    # standing ceiling, not a one-off.
    it 'cannot approve itself a grant wider than its own scopes' do
      verifier = SecureRandom.urlsafe_base64(64)
      challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)

      post '/api/v3/admin/oauth/authorize',
           params: { client_id: application.uid, redirect_uri: application.redirect_uri,
                     response_type: 'code', scope: 'write_orders',
                     code_challenge: challenge, code_challenge_method: 'S256' },
           headers: { 'Authorization' => "Bearer #{token}" }

      expect(response).to have_http_status(:forbidden)
      expect(Spree::OauthAccessGrant.where(application: application)).to be_empty
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
  # A grant authenticates AS the staff member who approved it, so every
  # guard written for "a human at the dashboard" now answers for an agent
  # too. These three asked what kind of credential had arrived instead of
  # what it held, and a read-only grant walked through all of them.
  describe 'a guard that was written before delegated credentials existed' do
    let(:read_only) { token_for('read_products', resource: '/api/v3/admin') }

    it 'refuses to let an agent rewrite the profile of the person who connected it' do
      patch '/api/v3/admin/me',
            params: { first_name: 'PWNED' }.to_json,
            headers: { 'Authorization' => "Bearer #{read_only}", 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:forbidden)
      expect(admin.reload.first_name).not_to eq('PWNED')
    end

    # The tag list is per taggable type, and its check began
    # `return unless current_api_key` — which an OAuth request never has.
    it 'refuses order tags to a grant that holds no read_orders' do
      get_with(read_only, '/api/v3/admin/tags?taggable_type=order')

      expect(response).to have_http_status(:forbidden)
    end

    it 'allows them to a grant that does' do
      get_with(token_for('read_orders', resource: '/api/v3/admin'),
               '/api/v3/admin/tags?taggable_type=order')

      expect(response).to have_http_status(:ok)
    end

    # `jwt_only` exempts a signed-in staff member from the scope gate because
    # their role already bounds them. A grant is bounded by something
    # narrower, and was taking the exemption.
    it 'refuses store settings to a grant that holds no read_settings' do
      get_with(read_only, '/api/v3/admin/store')

      expect(response).to have_http_status(:forbidden)
    end

    it 'allows them to a grant that does' do
      get_with(token_for('read_settings', resource: '/api/v3/admin'), '/api/v3/admin/store')

      expect(response).to have_http_status(:ok)
    end

    # /me is what a client reads to decide what to attempt, so reporting the
    # approver's whole role both oversells the grant and discloses the role.
    it 'reports what the credential holds rather than what its owner does' do
      get_with(read_only, '/api/v3/admin/me')

      expect(json_response['permission_keys']).to eq(['read_products'])
    end
  end

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
      expect(controller.send(:current_store)).to eq(store)
    end
  end
end
