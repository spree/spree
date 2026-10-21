require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Carts::TokensController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:cart) { create(:cart_with_line_items, customer: nil, store: store) }
  let!(:old_token) { cart.token }

  before { request.headers['X-Spree-Api-Key'] = api_key.token }

  describe 'PATCH #update' do
    it 'replaces the token, so the old one no longer opens the cart' do
      request.headers['X-Spree-Token'] = old_token

      patch :update, params: { cart_id: cart.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['token']).to eq(cart.reload.token)
      expect(cart.token).not_to eq(old_token)
    end

    it 'refuses a token that does not match' do
      request.headers['X-Spree-Token'] = 'not-the-token'

      patch :update, params: { cart_id: cart.prefixed_id }

      expect(response).to have_http_status(:forbidden)
      expect(cart.reload.token).to eq(old_token)
    end

    # The owner reaches their cart by session; without the token there is no
    # link to revoke, and no reason to let a session swap it.
    it 'refuses a signed-in owner who sends no token' do
      cart.update!(customer: user)
      request.headers['Authorization'] = "Bearer #{jwt_token}"

      patch :update, params: { cart_id: cart.prefixed_id }

      expect(response).to have_http_status(:forbidden)
      expect(cart.reload.token).to eq(old_token)
    end

    it 'does not reach a completed cart' do
      cart.update_columns(completed_at: Time.current)
      request.headers['X-Spree-Token'] = old_token

      patch :update, params: { cart_id: cart.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end
  end
end
