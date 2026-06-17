require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::MeController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  # /admin/me reflects the calling admin user — exercise JWT-only here
  # (sending a secret key would route to the API-key principal, which has
  # no Spree user to introspect).
  let(:headers) { { 'Authorization' => "Bearer #{admin_jwt_token}" } }

  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    subject { get :show, as: :json }

    it 'returns ok' do
      subject
      expect(response).to have_http_status(:ok)
    end

    it 'does not raise accessing the internal CanCanCan rules' do
      # Regression: `Spree::Ability#rules` is protected in cancancan 3.x —
      # the controller must use `send(:rules)` to serialize them. If this
      # test fails with a 500, the fix has been undone.
      expect { subject }.not_to raise_error
      expect(response.status).to eq(200)
      expect(response.body).to include('"permissions"')
    end

    it 'returns the current admin user' do
      subject
      expect(json_response['user']).to be_present
      expect(json_response['user']['email']).to eq(admin_user.email)
    end

    it 'returns an array of permissions' do
      subject
      expect(json_response['permissions']).to be_an(Array)
      expect(json_response['permissions']).not_to be_empty
    end

    it 'serializes each rule with allow, actions, subjects and has_conditions' do
      subject
      rule = json_response['permissions'].first
      expect(rule.keys).to match_array(%w[allow actions subjects has_conditions])
      expect(rule['allow']).to be_in([true, false])
      expect(rule['actions']).to be_an(Array)
      expect(rule['subjects']).to be_an(Array)
      expect(rule['has_conditions']).to be_in([true, false])
    end

    it 'preserves rule order matching Spree::Ability' do
      subject
      ability = Spree::Ability.new(admin_user, store: store)
      returned = json_response['permissions']
      expect(returned.length).to eq(ability.send(:rules).length)
    end

    it 'includes a manage all rule for admin users' do
      subject
      manage_all_rule = json_response['permissions'].find do |rule|
        rule['allow'] && rule['actions'].include?('manage') && rule['subjects'].include?('all')
      end
      expect(manage_all_rule).to be_present
    end

    context 'without authentication' do
      let(:headers) { {} }

      it 'returns unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated via a secret API key (no Spree user)' do
      # Regression: a secret-key principal has no user to introspect. The
      # controller must 404 (pointing at /api_keys/current) rather than 500
      # from serializing a nil user — see NoMethodError: undefined method 'email' for nil.
      let(:secret_api_key) { create(:api_key, :secret, store: store) }
      let(:headers) { { 'x-spree-api-key' => secret_api_key.plaintext_token } }

      it 'returns not found instead of raising' do
        expect { subject }.not_to raise_error
        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end
end
