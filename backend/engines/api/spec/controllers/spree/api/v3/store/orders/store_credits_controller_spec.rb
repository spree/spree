require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Orders::StoreCreditsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:order) { create(:order_with_line_items, user: user, store: store, state: 'payment') }
  let!(:store_credit_payment_method) { create(:store_credit_payment_method, stores: [store]) }
  let!(:store_credit) { create(:store_credit, user: user, store: store, amount: 100) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'POST #create' do
    it 'applies store credit to the order' do
      post :create, params: { order_id: order.to_param, amount: 10 }

      expect(response).to have_http_status(:ok)
      expect(order.reload.payments.store_credits.count).to eq(1)
    end

    it 'returns the updated order' do
      post :create, params: { order_id: order.to_param, amount: 10 }

      expect(json_response['id']).to eq(order.prefixed_id)
    end

    context 'without available store credit' do
      let(:user_without_credit) { create(:user) }
      let(:order_without_credit) { create(:order_with_line_items, user: user_without_credit, store: store, state: 'payment') }

      it 'returns an error' do
        jwt = Spree::Api::V3::TestingSupport.generate_jwt(user_without_credit)
        request.headers['Authorization'] = "Bearer #{jwt}"
        post :create, params: { order_id: order_without_credit.to_param, amount: 10 }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to be_present
      end
    end

    context 'authentication' do
      it 'requires authentication' do
        request.headers['Authorization'] = nil

        post :create, params: { order_id: order.to_param, amount: 10 }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent order' do
        post :create, params: { order_id: 'invalid', amount: 10 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'returns not found for other users order' do
        other_order = create(:order, store: store)

        post :create, params: { order_id: other_order.to_param, amount: 10 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'returns the updated order' do
      # First add store credit, then remove it
      Spree.checkout_add_store_credit_service.call(order: order, amount: 10)

      delete :destroy, params: { order_id: order.to_param }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(order.prefixed_id)
    end

    context 'authentication' do
      it 'requires authentication' do
        request.headers['Authorization'] = nil

        delete :destroy, params: { order_id: order.to_param }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent order' do
        delete :destroy, params: { order_id: 'invalid' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end
  end
end
