require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Orders::PaymentMethodsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:order) { create(:order_with_line_items, user: user, store: store, state: 'payment') }
  let!(:payment_method) { create(:credit_card_payment_method, stores: [store], display_on: 'both') }
  let!(:backend_only_pm) { create(:credit_card_payment_method, stores: [store], display_on: 'back_end') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
    it 'returns available payment methods for the order' do
      get :index, params: { order_id: order.to_param }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |pm| pm['id'] }).to include(payment_method.prefixed_id)
    end

    it 'excludes backend-only payment methods' do
      get :index, params: { order_id: order.to_param }

      expect(json_response['data'].map { |pm| pm['id'] }).not_to include(backend_only_pm.prefixed_id)
    end

    it 'includes payment method count in meta' do
      get :index, params: { order_id: order.to_param }

      expect(json_response['meta']['count']).to be_present
    end

    context 'with order token (guest)' do
      let(:guest_order) { create(:order_with_line_items, store: store, state: 'payment') }

      before { request.headers['Authorization'] = nil }

      it 'returns payment methods with valid order token' do
        request.headers['X-Spree-Order-Token'] = guest_order.token
        get :index, params: { order_id: guest_order.to_param }

        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to be_present
      end

      it 'returns not found without order token' do
        get :index, params: { order_id: guest_order.to_param }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent order' do
        get :index, params: { order_id: 'invalid' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'returns not found for other users order' do
        other_order = create(:order, store: store)

        get :index, params: { order_id: other_order.to_param }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end
  end
end
