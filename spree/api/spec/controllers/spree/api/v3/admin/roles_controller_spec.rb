require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::RolesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:admin_role) { Spree::Role.default_admin_role }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:role) { create(:role, name: 'support', permissions: %w[read_orders]) }

    it 'lists roles with permissions and mutability' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |r| r['name'] }
      expect(names).to include('admin', 'support')

      support = json_response['data'].find { |r| r['name'] == 'support' }
      expect(support['permissions']).to eq(%w[read_orders])
      expect(support['mutable']).to be true
      expect(support['users_count']).to eq(0)
    end

    # The staff Roles page feeds the staff role picker, so a role owned by
    # another resource would be assignable to store staff.
    it 'omits roles owned by another resource' do
      create(:role, name: 'vendor_manager', resource: create(:customer_group))

      get :index, as: :json

      names = json_response['data'].map { |r| r['name'] }
      expect(names).not_to include('vendor_manager')
    end

    it 'reports the admin role as immutable with the full catalog' do
      get :index, as: :json

      admin = json_response['data'].find { |r| r['name'] == 'admin' }
      expect(admin['mutable']).to be false
      expect(admin['permissions']).to eq(Spree.permissions.catalog_keys)
    end
  end

  describe 'POST #create' do
    it 'creates a role with catalog permissions' do
      post :create, params: { name: 'order_manager', description: 'Daily orders', permissions: %w[write_orders read_customers] }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('order_manager')
      expect(json_response['permissions']).to eq(%w[write_orders read_customers])
      expect(json_response['description']).to eq('Daily orders')
    end

    it 'rejects unknown permission keys as validation errors' do
      post :create, params: { name: 'broken', permissions: %w[write_bogus] }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    context 'as a staffer with limited permissions' do
      let(:staffer) do
        create(:admin_user, :without_admin_role).tap do |user|
          create(:role_user, user: user,
                 role: create(:role, name: 'team_manager', permissions: %w[write_staff read_orders]))
        end
      end
      let(:headers) do
        { 'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(staffer, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}" }
      end

      it 'allows granting keys within its own grant' do
        post :create, params: { name: 'viewer', permissions: %w[read_orders] }, as: :json

        expect(response).to have_http_status(:created)
      end

      it 'forbids granting keys beyond its own grant' do
        post :create, params: { name: 'sneaky', permissions: %w[write_products] }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(json_response.dig('error', 'details', 'excess_permissions')).to include('write_products')
        expect(Spree::Role.find_by(name: 'sneaky')).to be_nil
      end

      # A role owned by another resource (a marketplace vendor) confers nothing
      # in the store admin, so it must not widen what the caller may grant.
      it 'ignores keys the caller holds only on a non-store resource' do
        Spree.permissions.register_resource(
          :products, group: :catalog, audiences: %i[dummy_model], subjects: -> { [Spree::Product] }
        )
        create(:role_user, user: staffer,
               role: create(:role, name: 'vendor_catalog', permissions: %w[write_products],
                                   resource: Spree::DummyModel.create!(name: 'Vendor A')))

        post :create, params: { name: 'sneaky', permissions: %w[write_products] }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(Spree::Role.find_by(name: 'sneaky')).to be_nil
      ensure
        Spree.permissions.reset!
      end

      # Privileges held on OTHER stores don't count: the caller's grant is
      # their roles on the store the request runs against.
      it 'ignores keys the caller holds only on a different store' do
        store_b = create(:store)
        create(:role_user, user: staffer,
               role: create(:role, name: 'b_products', permissions: %w[write_products], resource: store_b))

        post :create, params: { name: 'sneaky', permissions: %w[write_products] }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'via a secret API key with limited scopes' do
      let(:caller_key) { create(:api_key, :secret, store: store, scopes: %w[write_staff read_orders]) }
      let(:headers) { { 'x-spree-api-key' => caller_key.plaintext_token } }

      it 'is bounded by the key scopes' do
        post :create, params: { name: 'sneaky', permissions: %w[write_products] }, as: :json

        expect(response).to have_http_status(:forbidden)
      end

      it 'allows granting within the key scopes' do
        post :create, params: { name: 'viewer', permissions: %w[read_orders] }, as: :json

        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'PATCH #update' do
    let!(:role) { create(:role, name: 'support', permissions: %w[read_orders]) }

    it 'updates name, description and permissions' do
      patch :update, params: { id: role.prefixed_id, name: 'helpdesk', permissions: %w[read_orders read_customers] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(role.reload.name).to eq('helpdesk')
      expect(role.permissions).to eq(%w[read_orders read_customers])
    end

    it 'rejects renaming the admin role' do
      patch :update, params: { id: admin_role.prefixed_id, name: 'owner' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(admin_role.reload.name).to eq('admin')
    end

    it 'rejects changing admin role permissions' do
      patch :update, params: { id: admin_role.prefixed_id, permissions: %w[read_orders] }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes an unreferenced role' do
      role = create(:role, name: 'obsolete')

      delete :destroy, params: { id: role.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::Role.find_by(name: 'obsolete')).to be_nil
    end

    it 'refuses to delete the admin role' do
      delete :destroy, params: { id: admin_role.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::Role.find_by(name: 'admin')).to be_present
    end

    it 'refuses to delete a role still assigned to staff' do
      role = create(:role, name: 'in_use')
      create(:role_user, user: create(:admin_user, :without_admin_role), role: role)

      delete :destroy, params: { id: role.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::Role.find_by(name: 'in_use')).to be_present
    end
  end
end
