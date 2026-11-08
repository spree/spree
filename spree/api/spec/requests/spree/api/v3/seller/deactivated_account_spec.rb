require 'spec_helper'

# Sellers sign in with staff accounts, so a deactivated account
# (Spree::AccountDeactivation) must lose the seller panel too.
RSpec.describe 'Deactivated staff accounts on the Seller API', type: :request do
  include_context 'API v3 Seller'

  let(:password) { 'password123' }
  let(:seller_user) do
    create(:admin_user, :without_admin_role, password: password, password_confirmation: password).
      tap { |user| seller.add_user(user, seller_role) }
  end

  def json
    JSON.parse(response.body)
  end

  def log_in(with: password)
    post '/api/v3/seller/auth/login', params: { email: seller_user.email, password: with }
  end

  it 'refuses to sign in once the password is proven' do
    seller_user.deactivate!

    log_in

    expect(response).to have_http_status(:forbidden)
    expect(json['error']['code']).to eq('account_deactivated')
  end

  it 'answers a wrong password exactly as for any account' do
    seller_user.deactivate!

    log_in(with: 'wrong-password')

    expect(response).to have_http_status(:unauthorized)
    expect(json['error']['code']).to eq('authentication_failed')
  end

  it 'stops an access token issued before deactivation on the next request' do
    get '/api/v3/seller/me', headers: seller_headers
    expect(response).to have_http_status(:ok)

    seller_user.deactivate!

    get '/api/v3/seller/me', headers: seller_headers
    expect(response).to have_http_status(:unauthorized)
  end

  describe 'refreshing a session' do
    before { log_in }

    it 'fails once deactivation has ended the session' do
      seller_user.deactivate!

      post '/api/v3/seller/auth/refresh'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses a surviving refresh token and deletes it' do
      seller_user.update_column(:deactivated_at, Time.current)

      post '/api/v3/seller/auth/refresh'

      expect(response).to have_http_status(:forbidden)
      expect(json['error']['code']).to eq('account_deactivated')
      expect(Spree::RefreshToken.where(user: seller_user)).to be_empty
    end
  end

  it 'refuses an invitation to another seller once the password is proven' do
    other_seller = create(:seller, :approved, store: store)
    invitation = create(:invitation, resource: other_seller, inviter: create(:admin_user),
                                     email: seller_user.email, role: other_seller.default_user_role)
    seller_user.deactivate!

    post "/api/v3/seller/auth/invitations/#{invitation.prefixed_id}/accept",
         params: { token: invitation.token, password: password }

    expect(response).to have_http_status(:forbidden)
    expect(json['error']['code']).to eq('account_deactivated')
    expect(other_seller.reload.users).not_to include(seller_user)
  end

  describe 'resetting the password' do
    it 'sends nothing for a deactivated account and answers as for any address' do
      seller_user.deactivate!
      expect_any_instance_of(Spree.admin_user_class).not_to receive(:publish_event)

      post '/api/v3/seller/auth/password_resets', params: { email: seller_user.email }

      expect(response).to have_http_status(:accepted)
    end

    it 'refuses a link sent before deactivation, leaving the password unchanged' do
      token = seller_user.generate_token_for(:password_reset)
      seller_user.deactivate!

      patch "/api/v3/seller/auth/password_resets/#{token}",
            params: { password: 'new-password-123', password_confirmation: 'new-password-123' }

      expect(response).to have_http_status(:forbidden)
      expect(json['error']['code']).to eq('account_deactivated')
      expect(seller_user.reload.valid_password?(password)).to be(true)
    end
  end
end
