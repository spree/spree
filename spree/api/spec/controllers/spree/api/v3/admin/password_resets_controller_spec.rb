require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PasswordResetsController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  let!(:admin_user) { create(:admin_user, email: 'admin@example.com') }

  describe 'POST #create' do
    before do
      allow(Spree::Events).to receive(:enabled?).and_return(true)
    end
    it 'publishes the password reset event and returns 202' do
      allow(Spree::Events).to receive(:publish)

      post :create, params: { email: 'admin@example.com' }

      expect(response).to have_http_status(:accepted)
      expect(Spree::Events).to have_received(:publish).with(
        'admin_user.password_reset_requested',
        hash_including(reset_token: an_instance_of(String), email: 'admin@example.com', store_id: store.prefixed_id),
        anything
      )
    end

    it 'returns 202 for unknown emails without publishing (no enumeration)' do
      allow(Spree::Events).to receive(:publish)

      post :create, params: { email: 'nobody@example.com' }

      expect(response).to have_http_status(:accepted)
      expect(Spree::Events).not_to have_received(:publish)
    end

    it 'ignores redirect_url when no allowed origins are configured' do
      allow(Spree::Events).to receive(:publish)

      post :create, params: { email: 'admin@example.com', redirect_url: 'https://evil.example.com' }

      expect(Spree::Events).to have_received(:publish) do |_name, payload, _meta|
        expect(payload).not_to have_key(:redirect_url)
      end
    end
  end

  describe 'PATCH #update' do
    it 'sets the new password and returns a JWT with the admin user' do
      token = admin_user.generate_token_for(:password_reset)

      patch :update, params: { id: token, password: 'new-secret-123', password_confirmation: 'new-secret-123' }

      expect(response).to have_http_status(:ok)
      expect(json_response['token']).to be_present
      expect(json_response['user']['id']).to eq(admin_user.prefixed_id)
      expect(admin_user.reload.valid_password?('new-secret-123')).to be(true)
    end

    it 'revokes every pre-existing session, keeping only the fresh one' do
      stolen_token = Spree::RefreshToken.create_for(admin_user, request_env: {})
      token = admin_user.generate_token_for(:password_reset)

      patch :update, params: { id: token, password: 'new-secret-123', password_confirmation: 'new-secret-123' }

      expect(response).to have_http_status(:ok)
      expect(Spree::RefreshToken.exists?(stolen_token.id)).to be(false)
      expect(Spree::RefreshToken.where(user: admin_user).count).to eq(1)
    end

    it 'rejects an invalid token' do
      patch :update, params: { id: 'bogus', password: 'new-secret-123', password_confirmation: 'new-secret-123' }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
