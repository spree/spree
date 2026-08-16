# Helper module for generating JWT tokens in tests
module Spree
  module Api
    module V3
      module TestingSupport
        def self.generate_jwt(user, expiration: 1.hour.to_i, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_STORE)
          user_type = user.is_a?(Spree.admin_user_class) ? 'admin' : 'customer'
          payload = {
            user_id: user.id,
            user_type: user_type,
            jti: SecureRandom.uuid,
            iss: Spree::Api::V3::JwtAuthentication::JWT_ISSUER,
            aud: audience,
            exp: Time.current.to_i + expiration
          }
          secret = Spree::Api::Config[:jwt_secret_key].presence ||
                   Rails.application.credentials.jwt_secret_key ||
                   ENV['JWT_SECRET_KEY'] ||
                   Rails.application.secret_key_base
          JWT.encode(payload, secret, 'HS256')
        end
      end
    end
  end
end

shared_context 'API v3 Store' do
  let(:store) { @default_store || create(:store, default: true) }
  let(:api_key) { create(:api_key, :publishable, store: store) }
  let(:api_key_headers) { { 'x-spree-api-key' => api_key.token } }

  let(:user) { create(:user_with_addresses) }
  let(:jwt_token) { Spree::Api::V3::TestingSupport.generate_jwt(user) }
  let(:bearer_headers) { api_key_headers.merge('Authorization' => "Bearer #{jwt_token}") }

  before do
    # Stubbed on both branch anchors, not just the shared base — the anchors
    # define their own `current_store` (KeyStoreContext), which would shadow
    # a stub installed on the base class. Specs stub methods on this exact
    # `store` instance, so resolution must return it by identity.
    allow_any_instance_of(Spree::Api::V3::BaseController).to receive(:current_store).and_return(store)
    allow_any_instance_of(Spree::Api::V3::Store::BaseController).to receive(:current_store).and_return(store)
    allow_any_instance_of(Spree::Api::V3::Store::ResourceController).to receive(:current_store).and_return(store)
  end
end

shared_context 'API v3 Store authenticated' do
  include_context 'API v3 Store'

  let(:headers) { bearer_headers }
end

shared_context 'API v3 Store guest' do
  include_context 'API v3 Store'

  let(:headers) { api_key_headers }
end

shared_context 'API v3 Admin' do
  let(:store) { @default_store || create(:store, default: true) }
  let(:secret_api_key) { create(:api_key, :secret, store: store) }
  let(:api_key_headers) { { 'x-spree-api-key' => secret_api_key.plaintext_token } }

  let(:admin_user) { create(:admin_user) }
  let(:admin_jwt_token) { Spree::Api::V3::TestingSupport.generate_jwt(admin_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN) }
  let(:bearer_headers) { api_key_headers.merge('Authorization' => "Bearer #{admin_jwt_token}") }

  before do
    # See the 'API v3 Store' context — the admin anchors define their own
    # `current_store` (Admin::StoreContext), which shadows a base-class stub.
    allow_any_instance_of(Spree::Api::V3::BaseController).to receive(:current_store).and_return(store)
    allow_any_instance_of(Spree::Api::V3::Admin::BaseController).to receive(:current_store).and_return(store)
    allow_any_instance_of(Spree::Api::V3::Admin::ResourceController).to receive(:current_store).and_return(store)
  end
end

shared_context 'API v3 Admin authenticated' do
  include_context 'API v3 Admin'

  let(:headers) { bearer_headers }
end

# The marketplace seller panel. Deliberately no `current_vendor` stub: the
# header and the membership lookup behind it are what these specs exist to
# exercise, so stubbing them would test nothing.
shared_context 'API v3 Vendor' do
  let(:store) { @default_store || create(:store, default: true) }
  let(:vendor) { create(:vendor, :approved, store: store) }
  let(:vendor_role) { create(:role, name: 'Seller', resource: vendor, permissions: %w[write_products]) }
  let(:vendor_user) do
    create(:admin_user, :without_admin_role).tap { |user| vendor.add_user(user, vendor_role) }
  end

  let(:vendor_jwt_token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      vendor_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_VENDOR
    )
  end
  let(:vendor_headers) do
    { 'Authorization' => "Bearer #{vendor_jwt_token}", 'X-Spree-Vendor-Id' => vendor.prefixed_id }
  end
end

shared_context 'API v3 Vendor authenticated' do
  include_context 'API v3 Vendor'

  let(:headers) { vendor_headers }
end

# Authenticates as an admin whose ability is restricted to specific catalog
# permission keys, so authorization specs can assert what a limited role can
# and cannot do. Define `custom_permissions` (an array of catalog keys, e.g.
# `%w[read_orders write_products]`) in the including example. Roles are data,
# so nothing global is mutated.
shared_context 'API v3 Admin with custom permissions' do
  include_context 'API v3 Admin'

  let(:custom_permissions) { [] }
  # A role belongs to what it governs, so it must be the store under test.
  let(:custom_role) { create(:role, name: 'limited', permissions: custom_permissions, resource: store) }
  let(:custom_admin) { create(:admin_user, :without_admin_role) }
  let(:headers) do
    { 'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(custom_admin, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}" }
  end

  before do
    custom_admin.spree_roles << custom_role
  end
end

# Shared examples for common response patterns
shared_examples 'returns 200 OK' do
  it 'returns 200 status' do
    subject
    expect(response).to have_http_status(:ok)
  end
end

shared_examples 'returns 201 Created' do
  it 'returns 201 status' do
    subject
    expect(response).to have_http_status(:created)
  end
end

shared_examples 'returns 204 No Content' do
  it 'returns 204 status' do
    subject
    expect(response).to have_http_status(:no_content)
  end
end

shared_examples 'returns 401 Unauthorized' do
  it 'returns 401 status' do
    subject
    expect(response).to have_http_status(:unauthorized)
  end
end

shared_examples 'returns 403 Forbidden' do
  it 'returns 403 status' do
    subject
    expect(response).to have_http_status(:forbidden)
  end
end

shared_examples 'returns 404 Not Found' do
  it 'returns 404 status' do
    subject
    expect(response).to have_http_status(:not_found)
  end
end

shared_examples 'returns 422 Unprocessable Entity' do
  it 'returns 422 status' do
    subject
    expect(response).to have_http_status(:unprocessable_content)
  end
end

shared_examples 'requires API key' do
  context 'without API key' do
    let(:headers) { {} }

    it 'returns 401 unauthorized' do
      subject
      expect(response).to have_http_status(:unauthorized)
      expect(json_response[:error]).to include('API key')
    end
  end
end

shared_examples 'requires authentication' do
  context 'without JWT token' do
    let(:headers) { api_key_headers }

    it 'returns 401 unauthorized' do
      subject
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
