require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::DiagnosticsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:headers) { { 'Authorization' => "Bearer #{admin_jwt_token}" } }

  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    subject { get :show, as: :json }

    it 'returns the report and its Markdown' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('spree_version' => Spree.version, 'errors' => [])
      expect(json_response['sections'].pluck('key')).to include('platform', 'runtime', 'infrastructure')
      expect(json_response['markdown']).not_to include(store.name)
      expect(json_response['issue_url']).to start_with(Spree::Diagnostics::ISSUE_URL)
    end

    it 'adds the browser it was opened in' do
      request.headers['User-Agent'] = 'Mozilla/5.0 Test'

      subject

      client = json_response['sections'].find { |section| section['key'] == 'client' }
      expect(client['rows']).to eq([{ 'label' => 'User agent', 'value' => 'Mozilla/5.0 Test' }])
    end

    it "adds the caller's @spree packages and drops anything else" do
      get :show, params: { packages: '@spree/dashboard@6.0.4,@spree/admin-sdk@6.0.4-rc.1,left-pad@1.0.0,@spree/x@<b>' }, as: :json

      dashboard = json_response['sections'].find { |section| section['key'] == 'dashboard' }
      expect(dashboard['rows']).to eq([{ 'label' => '@spree/dashboard', 'value' => '6.0.4' },
                                       { 'label' => '@spree/admin-sdk', 'value' => '6.0.4-rc.1' }])
    end

    it 'leaves the section out when the caller sends no packages' do
      subject

      expect(json_response['sections'].pluck('key')).not_to include('dashboard')
    end

    context 'as a staffer who cannot manage the store' do
      let(:staffer) do
        create(:admin_user, :without_admin_role).tap do |user|
          create(:role_user, user: user, role: create(:role, name: 'orders_only', permissions: %w[write_orders]))
        end
      end
      let(:headers) do
        { 'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(staffer, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}" }
      end

      it 'is forbidden, so the running version stays hidden' do
        subject

        expect(response).to have_http_status(:forbidden)
        expect(response.body).not_to include(Spree.version)
      end
    end

    context 'when authenticated via a secret API key' do
      let(:headers) { { 'x-spree-api-key' => secret_api_key.plaintext_token } }

      it 'responds as if the endpoint did not exist' do
        subject

        expect(response).to have_http_status(:not_found)
        expect(response.body).not_to include(Spree.version)
      end
    end
  end
end
