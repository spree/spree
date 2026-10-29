require 'spec_helper'

# A deactivated staff account (Spree::AccountDeactivation) must lose every way
# back in, not only the login form. The SSO callback is covered in the auth
# controller spec.
RSpec.describe 'Deactivated staff accounts on the Admin API', type: :request do
  include_context 'API v3 Admin'

  let(:password) { 'password123' }
  let(:admin_user) { create(:admin_user, password: password, password_confirmation: password) }

  def json
    JSON.parse(response.body)
  end

  def log_in(with: password)
    post '/api/v3/admin/auth/login', params: { email: admin_user.email, password: with }
  end

  describe 'signing in' do
    it 'is refused once the password is proven, with no session' do
      admin_user.deactivate!

      log_in

      expect(response).to have_http_status(:forbidden)
      expect(json['error']['code']).to eq('account_deactivated')
      expect(response.headers['Set-Cookie'].to_s).not_to include('spree_admin_refresh_token=')
    end

    # Telling a stranger the account is switched off would confirm it exists.
    it 'answers a wrong password exactly as for any account' do
      admin_user.deactivate!

      log_in(with: 'wrong-password')

      expect(response).to have_http_status(:unauthorized)
      expect(json['error']['code']).to eq('authentication_failed')
    end
  end

  describe 'an access token issued before deactivation' do
    let(:headers) { { 'Authorization' => "Bearer #{admin_jwt_token}" } }

    it 'stops working on the next request' do
      get '/api/v3/admin/me', headers: headers
      expect(response).to have_http_status(:ok)

      admin_user.deactivate!

      get '/api/v3/admin/me', headers: headers
      expect(response).to have_http_status(:unauthorized)
    end

    it 'works again once the account is reactivated' do
      admin_user.deactivate!
      admin_user.reactivate!

      get '/api/v3/admin/me', headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'refreshing a session' do
    before { log_in }

    it 'fails once deactivation has ended the session' do
      admin_user.deactivate!

      post '/api/v3/admin/auth/refresh'

      expect(response).to have_http_status(:unauthorized)
      expect(json['error']['code']).to eq('invalid_refresh_token')
    end

    # A refresh token that outlived the deactivation, as a refresh already
    # under way when it happened would leave it.
    it 'refuses a surviving refresh token and deletes it' do
      admin_user.update_column(:deactivated_at, Time.current)

      post '/api/v3/admin/auth/refresh'

      expect(response).to have_http_status(:forbidden)
      expect(json['error']['code']).to eq('account_deactivated')
      expect(Spree::RefreshToken.where(user: admin_user)).to be_empty
    end
  end

  describe 'an OAuth app token' do
    let(:application) do
      store.oauth_applications.create!(name: 'Assistant', redirect_uri: 'https://example.test/cb', confidential: false)
    end
    let!(:oauth_token) do
      Spree::OauthAccessToken.create!(
        application: application, resource_owner: admin_user, scopes: 'read_products',
        expires_in: 2.hours.to_i, resource: Spree::Api::Oauth.resource_identifier(:admin)
      )
    end
    let(:headers) { { 'Authorization' => "Bearer #{oauth_token.plaintext_token}" } }

    it 'is revoked by deactivation' do
      get '/api/v3/admin/products', headers: headers
      expect(response).to have_http_status(:ok)

      admin_user.deactivate!

      expect(oauth_token.reload).to be_revoked
      get '/api/v3/admin/products', headers: headers
      expect(response).to have_http_status(:unauthorized)
    end

    it 'is refused for a deactivated account even when not revoked' do
      admin_user.update_column(:deactivated_at, Time.current)

      get '/api/v3/admin/products', headers: headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'accepting an invitation' do
    # Staff of another store, invited to this one.
    let(:invitee) { create(:admin_user, :without_admin_role, password: password, password_confirmation: password) }
    let!(:invitation) { create(:invitation, resource: store, email: invitee.email) }

    it 'is refused once the password is proven, and grants no role' do
      invitee.deactivate!

      expect do
        post "/api/v3/admin/auth/invitations/#{invitation.prefixed_id}/accept",
             params: { token: invitation.token, password: password }
      end.not_to change(Spree::RoleUser, :count)

      expect(response).to have_http_status(:forbidden)
      expect(json['error']['code']).to eq('account_deactivated')
      expect(Spree::Invitation.pending.exists?(invitation.id)).to be(true)
    end
  end

  describe 'resetting the password' do
    it 'sends nothing for a deactivated account and answers as for any address' do
      admin_user.deactivate!
      expect_any_instance_of(Spree.admin_user_class).not_to receive(:publish_event)

      post '/api/v3/admin/auth/password_resets', params: { email: admin_user.email }, headers: api_key_headers

      expect(response).to have_http_status(:accepted)
    end

    it 'still sends the reset email to an active account' do
      expect_any_instance_of(Spree.admin_user_class).to receive(:publish_event).
        with('admin_user.password_reset_requested', anything)

      post '/api/v3/admin/auth/password_resets', params: { email: admin_user.email }, headers: api_key_headers
    end

    it 'refuses a link sent before deactivation, leaving the password unchanged' do
      token = admin_user.generate_token_for(:password_reset)
      admin_user.deactivate!

      patch "/api/v3/admin/auth/password_resets/#{token}",
            params: { password: 'new-password-123', password_confirmation: 'new-password-123' },
            headers: api_key_headers

      expect(response).to have_http_status(:forbidden)
      expect(json['error']['code']).to eq('account_deactivated')
      expect(admin_user.reload.valid_password?(password)).to be(true)
    end
  end
end
