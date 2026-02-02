require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Orders::PaymentsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:order) { create(:order_with_line_items, user: user, store: store, state: 'payment') }
  let(:payment_method) { create(:credit_card_payment_method, stores: [store]) }
  let!(:payment) { create(:payment, order: order, payment_method: payment_method, amount: order.total) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
    it 'returns a list of payments for the order' do
      get :index, params: { order_id: order.to_param }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(1)
      expect(json_response['data'].first['id']).to eq(payment.prefix_id)
    end

    it 'includes payment method information' do
      get :index, params: { order_id: order.to_param }

      expect(json_response['data'].first['payment_method_id']).to eq(payment_method.prefix_id)
    end

    context 'with order token (guest)' do
      let(:guest_order) { create(:order_with_line_items, user: nil, store: store, state: 'payment') }
      let!(:guest_payment) { create(:payment, order: guest_order, payment_method: payment_method) }

      before { request.headers['Authorization'] = nil }

      it 'returns payments with valid order token' do
        request.headers['X-Spree-Order-Token'] = guest_order.token
        get :index, params: { order_id: guest_order.to_param }

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq(1)
      end

      it 'returns forbidden without order token' do
        get :index, params: { order_id: guest_order.to_param }

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['code']).to eq('access_denied')
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent order' do
        get :index, params: { order_id: 'invalid' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'returns forbidden for other users order' do
        other_order = create(:order, store: store)

        get :index, params: { order_id: other_order.to_param }

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['code']).to eq('access_denied')
      end
    end
  end

  describe 'GET #show' do
    it 'returns a single payment' do
      get :show, params: { order_id: order.to_param, id: payment.to_param }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(payment.prefix_id)
      expect(json_response['state']).to eq(payment.state)
      expect(json_response['amount']).to eq(payment.amount.to_s)
    end

    context 'error handling' do
      it 'returns not found for non-existent payment' do
        get :show, params: { order_id: order.to_param, id: 'invalid' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end

      it 'returns not found for payment from another order' do
        other_order = create(:order_with_line_items, user: user, store: store, state: 'payment')
        other_payment = create(:payment, order: other_order, payment_method: payment_method, amount: other_order.total)

        get :show, params: { order_id: order.to_param, id: other_payment.to_param }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end
end
