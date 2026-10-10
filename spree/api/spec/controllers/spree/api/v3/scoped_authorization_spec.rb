require 'spec_helper'

# Verifies the ScopedAuthorization concern that gates Admin API requests
# authenticated via secret API key. Uses OrdersController as a representative
# resource — the same mechanic applies to every admin controller via the
# `scoped_resource` declaration.
RSpec.describe Spree::Api::V3::Admin::OrdersController, type: :controller do
  render_views
  include_context 'API v3 Admin'

  let!(:order) { create(:order, store: store, state: 'cart') }
  let(:secret_key) { create(:api_key, :secret, store: store, created_by: admin_user, scopes: scopes) }

  before { request.headers['X-Spree-Api-Key'] = secret_key.plaintext_token }

  describe 'with required scope' do
    let(:scopes) { ['read_orders'] }

    it 'allows reads' do
      get :index, as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'without required scope' do
    let(:scopes) { ['read_customers'] }

    it 'returns 403 with access_denied + required_scope details' do
      get :index, as: :json

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body['error']['code']).to eq('access_denied')
      expect(body['error']['details']['required_scope']).to eq('read_orders')
    end
  end

  describe 'write action with read-only scope' do
    let(:scopes) { ['read_orders'] }

    it 'denies the write' do
      delete :destroy, params: { id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body['error']['code']).to eq('access_denied')
      expect(body['error']['details']['required_scope']).to eq('write_orders')
    end
  end

  describe 'write_X implies read_X' do
    let(:scopes) { ['write_orders'] }

    it 'allows reads' do
      get :index, as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'read_all alias' do
    let(:scopes) { ['read_all'] }

    it 'allows reads on any resource' do
      get :index, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'denies writes' do
      delete :destroy, params: { id: order.prefixed_id }, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'write_all alias' do
    let(:scopes) { ['write_all'] }

    it 'allows reads' do
      get :index, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'allows writes' do
      delete :destroy, params: { id: order.prefixed_id }, as: :json
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'JWT-authenticated request' do
    # JWT staff pass through the same key gate: their roles' catalog keys play
    # the role scopes play for secret keys (docs/plans/6.0-admin-rbac.md).
    before do
      request.headers['X-Spree-Api-Key'] = nil
      request.headers['Authorization'] = "Bearer #{jwt_token}"
    end

    let(:scopes) { ['read_customers'] } # irrelevant — JWT auth doesn't read key scopes

    context 'as a full admin' do
      let(:jwt_token) { admin_jwt_token }

      it 'passes the key gate' do
        get :index, as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as a staffer whose roles grant the required key' do
      let(:staffer) do
        create(:admin_user, :without_admin_role).tap do |user|
          create(:role_user, user: user, role: create(:role, name: 'viewer', permissions: %w[read_orders], resource: store))
        end
      end
      let(:jwt_token) { Spree::Api::V3::TestingSupport.generate_jwt(staffer, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN) }

      it 'allows the read' do
        get :index, as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as a staffer whose roles lack the required key' do
      let(:staffer) do
        create(:admin_user, :without_admin_role).tap do |user|
          create(:role_user, user: user, role: create(:role, name: 'other', permissions: %w[read_customers], resource: store))
        end
      end
      let(:jwt_token) { Spree::Api::V3::TestingSupport.generate_jwt(staffer, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN) }

      it 'denies with the missing permission named' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body['error']['code']).to eq('access_denied')
        expect(body['error']['details']['required_permission']).to eq('read_orders')
      end
    end
  end

  # A staff member can delegate part of their authority to an agent or an app
  # through an OAuth grant. The grant is a ceiling on top of their roles, so
  # the gate asks for the intersection — approving a client must never be a
  # way to gain permissions the person does not have.
  describe 'request on a delegated credential' do
    before do
      request.headers['X-Spree-Api-Key'] = nil
      request.headers['Authorization'] = "Bearer #{admin_jwt_token}"
      allow(controller).to receive(:current_oauth_token).and_return(delegated_token)
    end

    let(:scopes) { ['read_customers'] }

    def token_granting(*granted)
      instance_double(Spree::OauthAccessToken, scopes: Doorkeeper::OAuth::Scopes.from_array(granted))
    end

    context 'when the grant covers the action' do
      let(:delegated_token) { token_granting('read_orders') }

      it 'allows it' do
        get :index, as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when the grant does not cover the action' do
      let(:delegated_token) { token_granting('read_products') }

      it 'denies it even though the admin could do it directly' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['error']['details']['required_permission']).to eq('read_orders')
      end
    end

    context 'when the grant names more than the person holds' do
      let(:staffer) do
        create(:admin_user, :without_admin_role).tap do |user|
          create(:role_user, user: user, role: create(:role, name: 'products-only', permissions: %w[read_products], resource: store))
        end
      end
      let(:delegated_token) { token_granting(*Spree.permissions.catalog_keys) }

      before do
        request.headers['Authorization'] =
          "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(staffer, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}"
      end

      it 'grants nothing extra' do
        get :index, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end

# Regression: the promotions controllers declare `scoped_resource :promotions`,
# but the scope pair was missing from Spree::ApiKey::SCOPES, so no key could
# ever be minted with it — promotion endpoints were reachable only via *_all.
RSpec.describe Spree::Api::V3::Admin::PromotionsController, type: :controller do
  render_views
  include_context 'API v3 Admin'

  let(:secret_key) { create(:api_key, :secret, store: store, created_by: admin_user, scopes: scopes) }

  before { request.headers['X-Spree-Api-Key'] = secret_key.plaintext_token }

  describe 'with read_promotions' do
    let(:scopes) { ['read_promotions'] }

    it 'allows reads' do
      get :index, as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'without a promotions scope' do
    let(:scopes) { ['read_orders'] }

    it 'denies with the promotions required_scope' do
      get :index, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['error']['details']['required_scope']).to eq('read_promotions')
    end
  end
end

# Regression for the Admin::BaseController ordering bypass: on this branch the
# `authorize_api_key_scope!` before_action runs BEFORE `authenticate_admin!`, so
# `current_api_key` is nil at guard time. The guard must resolve the secret key
# itself and fail CLOSED — never wave the request through — while still letting
# JWT-authenticated admins (authorized by CanCanCan, no secret key) pass.
RSpec.describe Spree::Api::V3::Admin::DashboardController, type: :controller do
  render_views
  include_context 'API v3 Admin'

  describe 'secret-key request reaching the guard before the key is resolved' do
    let(:secret_key) { create(:api_key, :secret, store: store, created_by: admin_user, scopes: scopes) }

    before { request.headers['X-Spree-Api-Key'] = secret_key.plaintext_token }

    context 'with the required scope' do
      let(:scopes) { ['read_dashboard'] }

      it 'enforces the scope and allows the read' do
        get :counters, as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without the required scope' do
      let(:scopes) { ['read_orders'] }

      it 'denies rather than silently skipping the scope check' do
        get :counters, as: :json

        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body['error']['code']).to eq('access_denied')
        expect(body['error']['details']['required_scope']).to eq('read_dashboard')
      end
    end
  end

  describe 'JWT-authenticated admin (no secret key)' do
    before do
      request.headers['X-Spree-Api-Key'] = nil
      request.headers['Authorization'] = "Bearer #{admin_jwt_token}"
    end

    it 'passes the key gate (admin holds the full catalog)' do
      get :counters, as: :json
      expect(response).to have_http_status(:ok)
    end
  end
end
