require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::AuthController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  let(:refresh_cookie_name) { Spree::Api::V3::Admin::AuthCookies::REFRESH_COOKIE_NAME.to_s }

  # Set-Cookie can be a String (joined) or Array of strings depending on Rack version.
  # Normalize to a single string for substring matching.
  def set_cookie_string
    Array(response.headers['Set-Cookie']).join("\n")
  end

  def set_cookie_for(name)
    set_cookie_string.split("\n").find { |line| line.start_with?("#{name}=") }
  end

  # Decode a signed cookie value the way Rails would on a subsequent request,
  # so tests can assert against the underlying refresh token without re-signing.
  def decode_signed_cookie(name)
    encoded = response.cookies[name]
    return nil if encoded.blank?
    request.cookies[name] = encoded
    request.cookie_jar.signed[name]
  end

  describe 'POST #create (login)' do
    let!(:existing_admin) { create(:admin_user, password: 'password123', password_confirmation: 'password123') }

    context 'with valid credentials' do
      it 'returns { token, user } and omits refresh_token from body' do
        post :create, params: { email: existing_admin.email, password: 'password123' }

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
        expect(json_response).not_to have_key('refresh_token')
        expect(json_response['user']['email']).to eq(existing_admin.email)
      end

      it 'sets a signed HttpOnly refresh cookie scoped to /api/v3/admin/auth' do
        post :create, params: { email: existing_admin.email, password: 'password123' }

        line = set_cookie_for('spree_admin_refresh_token')
        expect(line).to be_present
        expect(line).to include('httponly')
        expect(line).to include('path=/api/v3/admin/auth')
        # Over plain http, SameSite=Lax and no Secure flag
        expect(line).to include('samesite=lax')
        expect(line).not_to match(/;\s*secure/i)
      end

      it 'sets a Secure SameSite=None refresh cookie on https requests' do
        request.env['HTTPS'] = 'on'
        post :create, params: { email: existing_admin.email, password: 'password123' }

        line = set_cookie_for('spree_admin_refresh_token')
        expect(line).to be_present
        expect(line).to include('samesite=none')
        expect(line).to match(/;\s*secure/i)
      end

      it 'creates a RefreshToken row matching the signed cookie value' do
        expect {
          post :create, params: { email: existing_admin.email, password: 'password123' }
        }.to change(Spree::RefreshToken, :count).by(1)

        decoded = decode_signed_cookie(refresh_cookie_name)
        expect(decoded).to be_present
        expect(Spree::RefreshToken.find_by(token: decoded)).to be_present
      end

      it 'returns a JWT with admin audience and correct claims' do
        post :create, params: { email: existing_admin.email, password: 'password123' }

        payload = JWT.decode(json_response['token'], Rails.application.secret_key_base, true, algorithm: 'HS256').first
        expect(payload['aud']).to eq('admin_api')
        expect(payload['user_type']).to eq('admin')
        expect(payload['user_id']).to eq(existing_admin.id)
        expect(payload['exp']).to be > Time.current.to_i
      end
    end

    context 'invalid credentials' do
      it 'returns unauthorized for wrong password and sets no cookie' do
        post :create, params: { email: existing_admin.email, password: 'wrong' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_failed')
        expect(set_cookie_for('spree_admin_refresh_token')).to be_nil
      end

      it 'returns unauthorized for non-existent email' do
        post :create, params: { email: 'nonexistent@example.com', password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns the same error code for existing and non-existing emails (no timing leak)' do
        post :create, params: { email: existing_admin.email, password: 'wrong' }
        existing_code = json_response['error']['code']

        post :create, params: { email: 'nobody@example.com', password: 'wrong' }
        nonexistent_code = json_response['error']['code']

        expect(existing_code).to eq(nonexistent_code)
      end
    end

    context 'with unsupported provider' do
      it 'returns 400 invalid_provider' do
        post :create, params: { provider: 'unsupported', email: existing_admin.email, password: 'password123' }

        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']['code']).to eq('invalid_provider')
      end
    end

    context 'with a non-admin user' do
      let!(:regular_user) { create(:user, password: 'password123', password_confirmation: 'password123') }

      it 'returns unauthorized' do
        post :create, params: { email: regular_user.email, password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a custom identity provider' do
      let(:strategy_class) do
        Class.new(Spree::Authentication::Strategies::BaseStrategy) do
          def provider
            'okta'
          end

          def authenticate
            token = params[:token]
            return failure('invalid_token') if token != 'valid-jwt'

            user = find_or_create_user_from_oauth(
              provider: 'okta',
              uid:      'okta-admin-1',
              info:     { email: 'sso-admin@example.com', first_name: 'Sso', last_name: 'Admin' }
            )
            success(user)
          end
        end
      end

      around do |example|
        Spree.admin_authentication_strategies.add(:okta, strategy_class)
        example.run
      ensure
        Spree.admin_authentication_strategies.remove(:okta)
      end

      it 'dispatches to the registered strategy and returns a Spree admin JWT' do
        post :create, params: { provider: 'okta', token: 'valid-jwt' }

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
        expect(json_response['user']['email']).to eq('sso-admin@example.com')
        payload = JWT.decode(json_response['token'], Rails.application.secret_key_base, true, algorithm: 'HS256').first
        expect(payload['aud']).to eq('admin_api')
        expect(payload['user_type']).to eq('admin')
      end

      it 'sets the HttpOnly refresh cookie on a strategy success' do
        post :create, params: { provider: 'okta', token: 'valid-jwt' }

        line = set_cookie_for('spree_admin_refresh_token')
        expect(line).to be_present
        expect(line).to include('httponly')
      end

      it 'creates a UserIdentity mapped to an admin user on first login' do
        expect {
          post :create, params: { provider: 'okta', token: 'valid-jwt' }
        }.to change(Spree::UserIdentity, :count).by(1)

        identity = Spree::UserIdentity.last
        expect(identity.provider).to eq('okta')
        expect(identity.uid).to eq('okta-admin-1')
        expect(identity.user_type).to eq(Spree.admin_user_class.name)
      end

      it 'reuses the existing admin user on subsequent logins' do
        post :create, params: { provider: 'okta', token: 'valid-jwt' }
        first_user_id = json_response['user']['id']

        expect {
          post :create, params: { provider: 'okta', token: 'valid-jwt' }
        }.not_to change(Spree.admin_user_class, :count)

        expect(json_response['user']['id']).to eq(first_user_id)
      end

      it 'returns unauthorized when the strategy fails and sets no cookie' do
        post :create, params: { provider: 'okta', token: 'bad-jwt' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_failed')
        expect(json_response['error']['message']).to eq('invalid_token')
        expect(set_cookie_for('spree_admin_refresh_token')).to be_nil
      end
    end
  end

  describe 'POST #refresh' do
    let(:refresh_token) { create(:refresh_token, user: admin_user, ip_address: '127.0.0.1', user_agent: 'test') }

    context 'with a valid refresh cookie' do
      before do
        request.cookie_jar.signed[refresh_cookie_name] = refresh_token.token
      end

      it 'returns a new access token, rotates the refresh row, and omits refresh_token from body' do
        old_value = refresh_token.token

        post :refresh

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
        expect(json_response).not_to have_key('refresh_token')

        new_value = decode_signed_cookie(refresh_cookie_name)
        expect(new_value).to be_present
        expect(new_value).not_to eq(old_value)
        expect(Spree::RefreshToken.find_by(token: old_value)).to be_nil
        expect(Spree::RefreshToken.find_by(token: new_value)).to be_present
      end

      it 'returns user data and admin-audience JWT' do
        post :refresh

        expect(json_response['user']['email']).to eq(admin_user.email)
        payload = JWT.decode(json_response['token'], Rails.application.secret_key_base, true, algorithm: 'HS256').first
        expect(payload['aud']).to eq('admin_api')
        expect(payload['user_id']).to eq(admin_user.id)
      end
    end

    context 'with no refresh cookie' do
      it 'returns 401 invalid_refresh_token' do
        post :refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_refresh_token')
      end
    end

    context 'with a refresh cookie pointing to a missing/expired RefreshToken row' do
      it 'clears the refresh cookie and returns 401 invalid_refresh_token' do
        request.cookie_jar.signed[refresh_cookie_name] = 'rt_does_not_exist'

        post :refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_refresh_token')
        expect(set_cookie_for('spree_admin_refresh_token')).to include('=;')
      end
    end
  end

  describe 'POST #logout' do
    let(:refresh_token) { create(:refresh_token, user: admin_user, ip_address: '127.0.0.1', user_agent: 'test') }

    context 'with a valid refresh cookie' do
      before do
        request.cookie_jar.signed[refresh_cookie_name] = refresh_token.token
      end

      it 'destroys the RefreshToken row and clears the cookie' do
        token_id = refresh_token.id

        post :logout

        expect(response).to have_http_status(:no_content)
        expect(Spree::RefreshToken.where(id: token_id)).to be_empty
        expect(set_cookie_for('spree_admin_refresh_token')).to include('=;')
      end
    end

    context 'without any cookie (already logged out)' do
      it 'returns 204 idempotently' do
        post :logout

        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'response headers' do
    it 'sets no-store cache control' do
      post :create, params: { email: 'anyone@example.com', password: 'whatever' }
      expect(response.headers['Cache-Control']).to include('no-store')
    end
  end

  describe 'GET #providers' do
    let(:oidc_factory) do
      Spree::Authentication::Strategies::OidcStrategy.configure(
        issuer: 'https://idp.example.com',
        client_id: 'client-id',
        client_secret: 'client-secret',
        redirect_uri: 'https://shop.example.com/api/v3/admin/auth/callback/entra',
        label: 'Microsoft Entra ID'
      )
    end

    it 'lists the email provider on a default install' do
      get :providers

      expect(response).to have_http_status(:ok)
      expect(json_response['providers']).to eq([{ 'key' => 'email', 'kind' => 'password' }])
    end

    it 'does not require authentication' do
      get :providers

      expect(response).to have_http_status(:ok)
    end

    context 'with a redirect provider registered' do
      before do
        allow_any_instance_of(Spree::Authentication::Strategies::OidcStrategy).
          to receive(:discovery_document).
          and_return('authorization_endpoint' => 'https://idp.example.com/authorize')

        Spree.admin_authentication_strategies.add(:entra, oidc_factory)
      end

      after { Spree.admin_authentication_strategies.remove(:entra) }

      it 'describes it with a label and an authorization URL' do
        get :providers

        entra = json_response['providers'].find { |provider| provider['key'] == 'entra' }
        expect(entra['kind']).to eq('redirect')
        expect(entra['label']).to eq('Microsoft Entra ID')
        expect(entra['authorization_url']).to start_with('https://idp.example.com/authorize?')
      end

      # Unauthenticated endpoint — it must never leak credentials or internals.
      it 'exposes no client secret or class name' do
        get :providers

        expect(response.body).not_to include('client-secret')
        expect(response.body).not_to include('OidcStrategy')
      end
    end

    context 'when the email strategy is removed (SSO-only store)' do
      before { Spree.admin_authentication_strategies.remove(:email) }

      after do
        Spree.admin_authentication_strategies.add(:email, Spree::Authentication::Strategies::EmailPasswordStrategy)
      end

      it 'omits the password provider so the login page hides the form' do
        get :providers

        expect(json_response['providers'].map { |provider| provider['key'] }).not_to include('email')
      end
    end
  end

  describe 'GET #callback' do
    let!(:admin) { create(:admin_user, email: 'ada@example.com') }
    let(:oidc_factory) do
      Spree::Authentication::Strategies::OidcStrategy.configure(
        issuer: 'https://idp.example.com',
        client_id: 'client-id',
        client_secret: 'client-secret',
        redirect_uri: 'https://shop.example.com/api/v3/admin/auth/callback/entra',
        label: 'Microsoft Entra ID'
      )
    end

    # The state binds to the provider it was minted for, so the callback can
    # reject one provider's state replayed against another.
    def state_for(provider, expires_in: 15.minutes)
      Rails.application.message_verifier('spree/admin/oauth_state').generate(
        { provider: provider.to_s, nonce: SecureRandom.hex(16) },
        expires_in: expires_in
      )
    end

    let(:valid_state) { state_for('entra') }

    before { Spree.admin_authentication_strategies.add(:entra, oidc_factory) }

    after { Spree.admin_authentication_strategies.remove(:entra) }

    def stub_claims(claims)
      allow_any_instance_of(Spree::Authentication::Strategies::OidcStrategy).
        to receive(:exchange_code_for_tokens).and_return('id_token' => 'signed-token')
      allow_any_instance_of(Spree::Authentication::Strategies::OidcStrategy).
        to receive(:verify_id_token).and_return(claims)
    end

    context 'with a verified email matching an existing admin' do
      before do
        stub_claims('sub' => 'idp-subject-1', 'email' => admin.email, 'email_verified' => 'true')
      end

      it 'signs the admin in with the same token pair as password login' do
        get :callback, params: { provider: 'entra', code: 'auth-code', state: valid_state }

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
        expect(json_response['user']['email']).to eq(admin.email)
      end

      it 'sets the refresh cookie' do
        get :callback, params: { provider: 'entra', code: 'auth-code', state: valid_state }

        expect(set_cookie_for('spree_admin_refresh_token')).to be_present
      end

      it 'links the SSO identity to the existing account' do
        get :callback, params: { provider: 'entra', code: 'auth-code', state: valid_state }

        expect(admin.identities.find_by(provider: 'entra', uid: 'idp-subject-1')).to be_present
      end
    end

    context 'when the IdP does not assert a verified email' do
      before do
        stub_claims('sub' => 'idp-subject-1', 'email' => admin.email, 'email_verified' => 'false')
      end

      it 'refuses to claim the account' do
        get :callback, params: { provider: 'entra', code: 'auth-code', state: valid_state }

        expect(response).to have_http_status(:unauthorized)
        expect(admin.identities).to be_empty
      end
    end

    context 'when no account matches' do
      before do
        stub_claims('sub' => 'idp-subject-9', 'email' => 'stranger@example.com', 'email_verified' => 'true')
      end

      it 'rejects with account_not_provisioned rather than creating an admin' do
        expect {
          get :callback, params: { provider: 'entra', code: 'auth-code', state: valid_state }
        }.not_to change(Spree.admin_user_class, :count)

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('account_not_provisioned')
      end
    end

    describe 'CSRF state' do
      before do
        stub_claims('sub' => 'idp-subject-1', 'email' => admin.email, 'email_verified' => 'true')
      end

      it 'rejects a forged state' do
        get :callback, params: { provider: 'entra', code: 'auth-code', state: 'forged' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_oauth_state')
      end

      it 'rejects a missing state' do
        get :callback, params: { provider: 'entra', code: 'auth-code' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_oauth_state')
      end

      it 'rejects an expired state' do
        expired = Timecop.travel(20.minutes.ago) { state_for('entra') }

        get :callback, params: { provider: 'entra', code: 'auth-code', state: expired }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_oauth_state')
      end

      # A state minted for one provider must not authorize a different one.
      it 'rejects a state minted for another provider' do
        get :callback, params: { provider: 'entra', code: 'auth-code', state: state_for('other') }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_oauth_state')
      end
    end

    context 'with an unregistered provider' do
      # State is provider-bound and checked first, so a state minted for another
      # provider is rejected before the registry is ever consulted.
      it 'rejects another provider\'s state before looking the provider up' do
        get :callback, params: { provider: 'nope', code: 'auth-code', state: valid_state }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_oauth_state')
      end

      it 'returns invalid_provider once the state matches' do
        get :callback, params: { provider: 'nope', code: 'auth-code', state: state_for('nope') }

        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']['code']).to eq('invalid_provider')
      end
    end
  end
end
