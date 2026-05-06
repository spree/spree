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
        # In dev/test env (non-production), SameSite=Lax and no Secure flag
        expect(line).to include('samesite=lax')
        expect(line).not_to match(/;\s*secure/i)
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
  end

  describe 'POST #refresh' do
    let(:refresh_token) { Spree::RefreshToken.create_for(admin_user, request_env: { ip_address: '127.0.0.1', user_agent: 'test' }) }

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
    let(:refresh_token) { Spree::RefreshToken.create_for(admin_user, request_env: { ip_address: '127.0.0.1', user_agent: 'test' }) }

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
end
