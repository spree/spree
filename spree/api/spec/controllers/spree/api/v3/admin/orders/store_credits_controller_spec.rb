require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::StoreCreditsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:customer) { create(:user) }
  let!(:order) { create(:order_with_line_items, store: store, user: customer) }
  let!(:store_credit) { create(:store_credit, store: store, user: customer, amount: 50.00) }
  let!(:store_credit_payment_method) { create(:store_credit_payment_method) }

  before { request.headers.merge!(headers) }

  describe 'POST #create' do
    it 'applies store credit to the order' do
      post :create, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
      expect(order.reload.payments.store_credits.any?).to be true
    end

    context 'with explicit amount' do
      it 'applies up to the requested amount' do
        post :create, params: { order_id: order.prefixed_id, amount: 5.00 }, as: :json

        expect(response).to have_http_status(:created)
        applied = order.reload.payments.store_credits.sum(:amount)
        expect(applied).to eq(5.00)
      end
    end

    context 'when explicit amount exceeds available balance' do
      it 'caps at the available store credit balance' do
        post :create, params: { order_id: order.prefixed_id, amount: 9999.99 }, as: :json

        expect(response).to have_http_status(:created)
        applied = order.reload.payments.store_credits.sum(:amount)
        # Available balance ($50), capped at order outstanding ($110), so $50 applies
        expect(applied).to eq(store_credit.amount)
      end
    end

    context 'when the customer has no store credit balance' do
      let(:customer) { create(:user) }
      let!(:store_credit) { nil }

      it 'returns 422' do
        post :create, params: { order_id: order.prefixed_id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when the order has no customer' do
      let!(:order) { create(:order_with_line_items, store: store, user: nil) }

      it 'returns 422 (no customer means no store credit)' do
        post :create, params: { order_id: order.prefixed_id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when order belongs to a different store' do
      let!(:other_store) { create(:store) }
      let!(:order) { create(:order_with_line_items, store: other_store, user: customer) }

      it 'returns 404' do
        post :create, params: { order_id: order.prefixed_id }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when store credit was applied' do
      before do
        Spree.checkout_add_store_credit_service.call(order: order)
      end

      it 'removes store credit from the order' do
        delete :destroy, params: { order_id: order.prefixed_id }, as: :json

        expect(response).to have_http_status(:no_content)
        expect(order.reload.payments.store_credits.valid).to be_empty
      end
    end

    context 'when no store credit was applied' do
      it 'returns 204 (idempotent)' do
        delete :destroy, params: { order_id: order.prefixed_id }, as: :json

        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'API-key scope enforcement' do
    let(:headers) { { 'x-spree-api-key' => api_key.plaintext_token } }

    context 'with a key holding only write_store_credits' do
      let(:api_key) { create(:api_key, :secret, store: store, scopes: ['write_store_credits']) }

      it 'forbids applying store credit to the order' do
        post :create, params: { order_id: order.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['details']['required_scope']).to eq('write_orders')
      end
    end

    context 'with a key holding write_orders' do
      let(:api_key) { create(:api_key, :secret, store: store, scopes: ['write_orders']) }

      it 'allows applying store credit to the order' do
        post :create, params: { order_id: order.prefixed_id }, as: :json

        expect(response).to have_http_status(:created)
      end
    end
  end
end
