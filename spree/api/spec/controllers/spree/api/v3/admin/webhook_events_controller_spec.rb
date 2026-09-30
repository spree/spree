require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::WebhookEventsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists every declared event' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('name')).to eq(Spree::Events.catalog.all.map(&:name))
      expect(json_response['meta']['count']).to eq(Spree::Events.catalog.all.size)
    end

    it 'marks credential events with the permission they need, and deprecated aliases with their replacement' do
      get :index, as: :json

      events = json_response['data'].index_by { |entry| entry['name'] }
      expect(events['customer.password_reset_requested']).to include(
        'group' => 'customer', 'credential' => true, 'credential_permission' => 'write_customers'
      )
      expect(events['order.completed']).to include('deprecated' => true, 'replaced_by' => 'order.placed')
      expect(events['order.placed']).to include('credential' => false, 'deprecated' => false, 'replaced_by' => nil)
    end

    context 'with a staff JWT lacking the webhooks permission' do
      let(:staffer) do
        create(:admin_user, :without_admin_role).tap do |user|
          create(:role_user, user: user, role: create(:role, name: 'viewer', permissions: %w[read_orders], resource: store))
        end
      end
      let(:headers) do
        { 'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(staffer, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}" }
      end

      it 'is refused' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
