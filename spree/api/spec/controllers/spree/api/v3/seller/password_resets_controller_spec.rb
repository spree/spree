require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::PasswordResetsController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  before { allow(Spree::Events).to receive(:enabled?).and_return(true) }

  describe 'POST #create' do
    # The seller and its role publish events of their own as they are built,
    # so they are created before the spy goes up — otherwise every assertion
    # below has to reason about calls this controller never made.
    before do
      seller_user
      allow(Spree::Events).to receive(:publish)
    end

    it 'publishes the reset event and returns 202' do
      post :create, params: { email: seller_user.email }, as: :json

      expect(response).to have_http_status(:accepted)
      expect(Spree::Events).to have_received(:publish).with(
        'seller_user.password_reset_requested',
        hash_including(reset_token: an_instance_of(String), email: seller_user.email, store_id: store.prefixed_id),
        anything
      )
    end

    it 'returns 202 for unknown emails without publishing (no enumeration)' do
      post :create, params: { email: 'nobody@example.com' }, as: :json

      expect(response).to have_http_status(:accepted)
      expect(Spree::Events).not_to have_received(:publish)
    end

    # Staff share the user class, so matching an address is not enough: a store
    # admin who runs no seller has no panel to be sent to.
    it 'says nothing different for a staff member who runs no seller' do
      staff = create(:admin_user, email: 'staff@example.com')

      post :create, params: { email: staff.email }, as: :json

      expect(response).to have_http_status(:accepted)
      expect(Spree::Events).not_to have_received(:publish)
    end

    it 'ignores redirect_url when no allowed origins are configured' do
      post :create, params: { email: seller_user.email, redirect_url: 'https://evil.example.com' }, as: :json

      expect(Spree::Events).to have_received(:publish).
        with('seller_user.password_reset_requested', hash_excluding(:redirect_url), anything)
    end

    it 'ignores a redirect_url outside the store allowed origins' do
      store.allowed_origins.create!(origin: 'https://sellers.example.com')

      post :create, params: { email: seller_user.email, redirect_url: 'https://evil.example.com' }, as: :json

      expect(Spree::Events).to have_received(:publish).
        with('seller_user.password_reset_requested', hash_excluding(:redirect_url), anything)
    end

    # The store follows the seller, never `current_store` — which on this
    # unauthenticated endpoint is just the default store. Judged against that,
    # one marketplace's allowlist would approve a live reset token mailed to
    # another marketplace's seller.
    context 'when the seller belongs to a store other than the default' do
      let(:other_store) { create(:store) }
      let(:other_seller) { create(:seller, :approved, store: other_store) }
      let(:other_role) do
        create(:role, name: 'Other seller', resource: other_seller, permissions: %w[write_products])
      end
      let(:other_user) do
        create(:admin_user, :without_admin_role).tap { |user| other_seller.add_user(user, other_role) }
      end

      before do
        other_user
        allow(Spree::Events).to receive(:publish)
      end

      it 'refuses a redirect_url only the default store has vouched for' do
        store.allowed_origins.create!(origin: 'https://sellers.default-store.test')

        post :create,
             params: { email: other_user.email, redirect_url: 'https://sellers.default-store.test/reset-password' },
             as: :json

        expect(Spree::Events).to have_received(:publish).
          with('seller_user.password_reset_requested', hash_excluding(:redirect_url), anything)
      end

      it "keeps a redirect_url the seller's own store has vouched for" do
        other_store.allowed_origins.create!(origin: 'https://sellers.other-store.test')

        post :create,
             params: { email: other_user.email, redirect_url: 'https://sellers.other-store.test/reset-password' },
             as: :json

        expect(Spree::Events).to have_received(:publish).with(
          'seller_user.password_reset_requested',
          hash_including(
            redirect_url: 'https://sellers.other-store.test/reset-password',
            store_id: other_store.prefixed_id
          ),
          anything
        )
      end
    end

    it 'keeps a redirect_url the store has vouched for' do
      store.allowed_origins.create!(origin: 'https://sellers.example.com')

      post :create,
           params: { email: seller_user.email, redirect_url: 'https://sellers.example.com/reset-password' },
           as: :json

      expect(Spree::Events).to have_received(:publish).with(
        'seller_user.password_reset_requested',
        hash_including(redirect_url: 'https://sellers.example.com/reset-password'),
        anything
      )
    end
  end

  describe 'PATCH #update' do
    let(:reset_token) { seller_user.generate_token_for(:password_reset) }

    it 'sets the new password and signs the seller in' do
      patch :update,
            params: { id: reset_token, password: 'new-secret-123', password_confirmation: 'new-secret-123' },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['token']).to be_present
      expect(json_response['user']['email']).to eq(seller_user.email)
      expect(seller_user.reload.valid_password?('new-secret-123')).to be(true)
    end

    # The panel cannot make any other request until it knows which seller to
    # name in X-Spree-Seller-Id.
    it 'returns the sellers the user may act for' do
      patch :update,
            params: { id: reset_token, password: 'new-secret-123', password_confirmation: 'new-secret-123' },
            as: :json

      expect(json_response['sellers'].pluck('id')).to eq([seller.prefixed_id])
    end

    # The whole point of the branch: the session it mints must be redeemable on
    # the seller panel, which only accepts its own audience.
    it 'mints the fresh session for the seller surface' do
      patch :update,
            params: { id: reset_token, password: 'new-secret-123', password_confirmation: 'new-secret-123' },
            as: :json

      expect(Spree::RefreshToken.where(user: seller_user).last.audience).to eq('seller_api')
    end

    it 'revokes every pre-existing session, keeping only the fresh one' do
      stolen = Spree::RefreshToken.create_for(
        seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER, request_env: {}
      )
      token = reset_token

      patch :update, params: { id: token, password: 'new-secret-123', password_confirmation: 'new-secret-123' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(Spree::RefreshToken.exists?(stolen.id)).to be(false)
      expect(Spree::RefreshToken.where(user: seller_user).count).to eq(1)
    end

    it 'refuses an invalid token' do
      patch :update,
            params: { id: 'nonsense', password: 'new-secret-123', password_confirmation: 'new-secret-123' },
            as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('password_reset_token_invalid')
    end

    # Membership can be revoked between the email going out and the link being
    # opened, and a token that no longer belongs to a seller is reported exactly
    # as an expired one.
    it 'refuses a valid token whose seller membership has gone' do
      staff = create(:admin_user, email: 'staff@example.com')
      token = staff.generate_token_for(:password_reset)

      patch :update, params: { id: token, password: 'new-secret-123', password_confirmation: 'new-secret-123' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('password_reset_token_invalid')
      expect(staff.reload.valid_password?('new-secret-123')).to be(false)
    end

    it 'reports a password the model refuses' do
      patch :update, params: { id: reset_token, password: 'short', password_confirmation: 'short' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
