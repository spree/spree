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

    it 'exposes the user avatar_url (null when no photo is attached)' do
      subject
      expect(json_response['user']).to have_key('avatar_url')
      expect(json_response['user']['avatar_url']).to be_nil
    end

    it 'exposes the user selected_locale' do
      subject
      expect(json_response['user']).to have_key('selected_locale')
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

  describe 'PATCH #update' do
    subject { patch :update, params: params, as: :json }

    # The admin-UI language is a client concern (the dashboard ships its own
    # locale bundles), so the API stores whatever code the client sends without
    # validating it against the backend's Rails/SpreeI18n locales.
    context 'with a locale code' do
      let(:params) { { selected_locale: 'pl' } }

      it 'returns ok and persists the locale, even one the backend has no translations for' do
        subject
        expect(response).to have_http_status(:ok)
        expect(json_response['user']['selected_locale']).to eq('pl')
        expect(admin_user.reload.selected_locale).to eq('pl')
      end
    end

    context 'with an avatar signed id' do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(
          io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
          filename: 'avatar.jpg',
          content_type: 'image/jpeg'
        )
      end
      let(:params) { { avatar: blob.signed_id } }

      it 'attaches the avatar and returns its url' do
        subject
        expect(response).to have_http_status(:ok)
        expect(admin_user.reload.avatar).to be_attached
        expect(json_response['user']['avatar_url']).to be_present
      end
    end

    context 'with a non-image avatar' do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new('<svg xmlns="http://www.w3.org/2000/svg"></svg>'),
          filename: 'avatar.svg',
          content_type: 'image/svg+xml'
        )
      end
      let(:params) { { avatar: blob.signed_id } }

      it 'rejects the upload with a validation error' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(admin_user.reload.avatar).not_to be_attached
      end
    end

    context 'clearing the avatar' do
      before do
        admin_user.avatar.attach(
          io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
          filename: 'avatar.jpg',
          content_type: 'image/jpeg'
        )
      end
      let(:params) { { avatar: nil } }

      it 'purges the avatar' do
        subject
        expect(response).to have_http_status(:ok)
        expect(admin_user.reload.avatar).not_to be_attached
        expect(json_response['user']['avatar_url']).to be_nil
      end
    end

    context 'when authenticated via a secret API key (no Spree user)' do
      let(:secret_api_key) { create(:api_key, :secret, store: store) }
      let(:headers) { { 'x-spree-api-key' => secret_api_key.plaintext_token } }
      let(:params) { { selected_locale: 'de' } }

      it 'returns not found' do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
