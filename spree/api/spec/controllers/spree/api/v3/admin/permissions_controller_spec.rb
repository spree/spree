require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PermissionsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns the permission catalog' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      keys = json_response['data'].map { |entry| entry['key'] }
      expect(keys).to eq(Spree.permissions.catalog_keys)
    end

    it 'describes each entry with resource, kind, group and labels' do
      get :index, as: :json

      entry = json_response['data'].find { |e| e['key'] == 'write_orders' }
      expect(entry).to include(
        'resource' => 'orders',
        'kind' => 'write',
        'group' => 'orders',
        'label' => 'Orders'
      )
      expect(entry['description']).to be_present
      expect(entry['group_label']).to be_present
    end

    context 'with a limited staff JWT' do
      let(:staffer) do
        create(:admin_user, :without_admin_role).tap do |user|
          user.role_users.create!(role: create(:role, name: 'viewer', permissions: %w[read_orders]), resource: store)
        end
      end
      let(:headers) do
        { 'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(staffer, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}" }
      end

      it 'is readable regardless of the caller grant (vocabulary, not data)' do
        get :index, as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context 'unauthenticated' do
      let(:headers) { {} }

      it 'requires an admin credential' do
        get :index, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
