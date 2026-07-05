require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Carts::GiftCardsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:order) { create(:order_with_line_items, store: store, user: user) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'POST #create' do
    let!(:gift_card) { create(:gift_card, store: store, amount: 50, code: 'giftcard123') }

    it 'applies the gift card successfully' do
      post :create, params: { cart_id: order.prefixed_id, code: 'giftcard123' }

      expect(response).to have_http_status(:created)
      expect(json_response['id']).to start_with('cart_')
      expect(json_response['gift_card_total']).to be_present
      expect(json_response['amount_due']).to be_present
    end

    it 'is case insensitive' do
      post :create, params: { cart_id: order.prefixed_id, code: 'GIFTCARD123' }

      expect(response).to have_http_status(:created)
    end

    it 'returns error for non-existent gift card' do
      post :create, params: { cart_id: order.prefixed_id, code: 'NONEXISTENT' }

      expect(response).to have_http_status(:not_found)
      expect(json_response['error']).to be_present
    end

    it 'returns error for expired gift card' do
      gift_card.update!(expires_at: 1.day.ago)

      post :create, params: { cart_id: order.prefixed_id, code: 'giftcard123' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns error for redeemed gift card' do
      gift_card.update!(state: :redeemed, redeemed_at: Time.current, amount_used: gift_card.amount)

      post :create, params: { cart_id: order.prefixed_id, code: 'giftcard123' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    context 'with guest spree token' do
      let(:guest_order) { create(:order_with_line_items, store: store, user: nil) }

      before do
        request.headers['Authorization'] = nil
        request.headers['x-spree-token'] = guest_order.token
      end

      it 'allows access via spree token' do
        post :create, params: { cart_id: guest_order.prefixed_id, code: 'giftcard123' }

        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:gift_card) { create(:gift_card, store: store, amount: 50, code: 'giftcard123') }

    context 'with an applied gift card' do
      before do
        order.apply_gift_card(gift_card)
      end

      it 'removes the gift card successfully' do
        delete :destroy, params: { cart_id: order.prefixed_id, id: gift_card.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(order.reload.gift_card).to be_nil
      end
    end

    context 'without an applied gift card' do
      it 'returns success (no-op)' do
        delete :destroy, params: { cart_id: order.prefixed_id, id: gift_card.prefixed_id }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
