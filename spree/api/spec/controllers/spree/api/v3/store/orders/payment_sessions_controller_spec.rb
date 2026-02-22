require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Orders::PaymentSessionsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:order) { create(:order_with_line_items, user: user, store: store, state: 'payment') }
  let(:payment_method) { create(:bogus_payment_method, stores: [store]) }
  let!(:payment_session) do
    create(:bogus_payment_session,
           order: order,
           payment_method: payment_method,
           amount: order.total,
           external_data: { 'client_secret' => 'secret_123' })
  end

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'POST #create' do
    it 'creates a payment session' do
      post :create, params: {
        order_id: order.to_param,
        payment_method_id: payment_method.prefixed_id
      }

      expect(response).to have_http_status(:created)
      expect(json_response['id']).to be_present
      expect(json_response['status']).to eq('pending')
      expect(json_response['payment_method_id']).to eq(payment_method.prefixed_id)
      expect(json_response['order_id']).to eq(order.prefixed_id)
    end

    it 'passes external_data to the gateway' do
      post :create, params: {
        order_id: order.to_param,
        payment_method_id: payment_method.prefixed_id,
        external_data: { channel: 'Web' }
      }

      expect(response).to have_http_status(:created)
      expect(json_response['external_data']).to include('channel' => 'Web')
    end

    context 'with order token (guest)' do
      let(:guest_order) { create(:order_with_line_items, user: nil, store: store, state: 'payment') }

      before { request.headers['Authorization'] = nil }

      it 'creates payment session with valid order token' do
        request.headers['X-Spree-Order-Token'] = guest_order.token
        post :create, params: {
          order_id: guest_order.to_param,
          payment_method_id: payment_method.prefixed_id
        }

        expect(response).to have_http_status(:created)
      end

      it 'returns not found without order token' do
        post :create, params: {
          order_id: guest_order.to_param,
          payment_method_id: payment_method.prefixed_id
        }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent order' do
        post :create, params: {
          order_id: 'invalid',
          payment_method_id: payment_method.prefixed_id
        }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'returns not found for non-existent payment method' do
        post :create, params: {
          order_id: order.to_param,
          payment_method_id: 'invalid'
        }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end

  describe 'GET #show' do
    it 'returns a payment session' do
      get :show, params: { order_id: order.to_param, id: payment_session.to_param }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(payment_session.prefixed_id)
      expect(json_response['status']).to eq('pending')
      expect(json_response['amount']).to eq(payment_session.amount.to_s)
      expect(json_response['external_data']).to eq({ 'client_secret' => 'secret_123' })
    end

    context 'error handling' do
      it 'returns not found for non-existent payment session' do
        get :show, params: { order_id: order.to_param, id: 'invalid' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end

      it 'returns not found for payment session from another order' do
        other_order = create(:order_with_line_items, user: user, store: store, state: 'payment')
        other_session = create(:bogus_payment_session,
                               order: other_order,
                               payment_method: payment_method)

        get :show, params: { order_id: order.to_param, id: other_session.to_param }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates the payment session' do
      patch :update, params: {
        order_id: order.to_param,
        id: payment_session.to_param,
        amount: 50.00
      }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(payment_session.prefixed_id)
      expect(json_response['amount']).to eq('50.0')
    end
  end

  describe 'PATCH #complete' do
    it 'completes the payment session' do
      patch :complete, params: {
        order_id: order.to_param,
        id: payment_session.to_param,
        session_result: 'success'
      }

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('completed')
    end
  end
end
