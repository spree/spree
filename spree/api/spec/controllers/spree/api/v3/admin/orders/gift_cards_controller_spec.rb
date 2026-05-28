require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::GiftCardsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:order_with_line_items, store: store, state: 'cart') }
  let!(:gift_card) { create(:gift_card, store: store) }
  let!(:store_credit_payment_method) { create(:store_credit_payment_method) }

  before { request.headers.merge!(headers) }

  describe 'POST #create' do
    it 'applies the gift card to the order and returns the gift card' do
      post :create, params: { order_id: order.prefixed_id, code: gift_card.code }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['id']).to eq(gift_card.prefixed_id)
      expect(order.reload.gift_card).to eq(gift_card)
    end

    context 'when the code is provided in lowercase' do
      it 'matches case-insensitively' do
        post :create, params: { order_id: order.prefixed_id, code: gift_card.code.downcase }, as: :json

        expect(response).to have_http_status(:created)
      end
    end

    context 'when gift card code is unknown' do
      it 'returns 404' do
        post :create, params: { order_id: order.prefixed_id, code: 'UNKNOWN-CODE' }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when gift card belongs to a different store' do
      let!(:other_store) { create(:store) }
      let!(:gift_card) { create(:gift_card, store: other_store) }

      it 'returns 404 (cross-store leakage prevented)' do
        post :create, params: { order_id: order.prefixed_id, code: gift_card.code }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when gift card is expired' do
      let!(:gift_card) { create(:gift_card, store: store, expires_at: 1.day.ago) }

      it 'returns 422' do
        post :create, params: { order_id: order.prefixed_id, code: gift_card.code }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when gift card is fully redeemed' do
      let!(:gift_card) { create(:gift_card, :redeemed, store: store) }

      it 'returns 422' do
        post :create, params: { order_id: order.prefixed_id, code: gift_card.code }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when the order already has store credit applied (mutual exclusion)' do
      let(:customer) { create(:user) }
      let!(:order) { create(:order_with_line_items, store: store, user: customer) }
      let!(:store_credit) { create(:store_credit, store: store, user: customer, amount: 100) }

      before { Spree.checkout_add_store_credit_service.call(order: order) }

      it 'returns 422 (cannot mix gift card and store credit)' do
        post :create, params: { order_id: order.prefixed_id, code: gift_card.code }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when gift card currency does not match order currency' do
      let!(:gift_card) { create(:gift_card, store: store, currency: 'EUR') }

      it 'returns 422' do
        post :create, params: { order_id: order.prefixed_id, code: gift_card.code }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when gift card is restricted to a specific user but order has none' do
      let(:gift_card_owner) { create(:user) }
      let!(:gift_card) { create(:gift_card, store: store, user: gift_card_owner) }

      it 'returns 422' do
        post :create, params: { order_id: order.prefixed_id, code: gift_card.code }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when gift card is restricted to a different user than the order' do
      let(:gift_card_owner) { create(:user) }
      let(:order_customer) { create(:user) }
      let!(:order) { create(:order_with_line_items, store: store, user: order_customer) }
      let!(:gift_card) { create(:gift_card, store: store, user: gift_card_owner) }

      it 'returns 422' do
        post :create, params: { order_id: order.prefixed_id, code: gift_card.code }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when order belongs to a different store' do
      let!(:other_store) { create(:store) }
      let!(:order) { create(:order_with_line_items, store: other_store) }

      it 'returns 404 from the parent order lookup' do
        post :create, params: { order_id: order.prefixed_id, code: gift_card.code }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    before { order.update_column(:gift_card_id, gift_card.id) }

    it 'removes the gift card from the order' do
      delete :destroy, params: { order_id: order.prefixed_id, id: gift_card.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(order.reload.gift_card).to be_nil
    end

    context 'when the order has no gift card applied' do
      before { order.update_column(:gift_card_id, nil) }

      it 'still returns 204 (idempotent)' do
        delete :destroy, params: { order_id: order.prefixed_id, id: gift_card.prefixed_id }, as: :json

        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
