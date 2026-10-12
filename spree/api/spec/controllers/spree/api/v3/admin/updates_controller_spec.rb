require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::UpdatesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:headers) { { 'Authorization' => "Bearer #{admin_jwt_token}" } }
  let(:status) do
    Spree::UpdateStatus.new(
      current_version: Spree.version,
      checked_at: Time.utc(2026, 10, 3, 4),
      releases: [{ version: '99.0.1', url: 'https://github.com/spree/spree/releases/tag/v99.0.1', published_at: Time.utc(2026, 10, 2, 10, 51, 38) }]
    )
  end

  before do
    request.headers.merge!(headers)
    allow(Spree::UpdateCheck).to receive(:status).and_return(status)
  end

  describe 'GET #show' do
    subject { get :show, as: :json }

    it 'returns what the last check found' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq(
        'current_version' => Spree.version,
        'enabled' => true,
        'checked_at' => '2026-10-03T04:00:00.000Z',
        'update_available' => true,
        'latest_version' => '99.0.1',
        'latest_release_url' => 'https://github.com/spree/spree/releases/tag/v99.0.1',
        'latest_release_published_at' => '2026-10-02T10:51:38.000Z'
      )
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
