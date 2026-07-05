require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::OrdersController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #show' do
    let(:order) { create(:completed_order_with_totals, user: user, store: store) }

    context 'authenticated user' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'returns the order' do
        get :show, params: { id: order.to_param }

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(order.number)
      end

      it 'returns order with expected attributes' do
        get :show, params: { id: order.to_param }

        expect(json_response['id']).to eq(order.prefixed_id)
        expect(json_response['number']).to eq(order.number)
      end
    end

    context 'with spree token' do
      let(:guest_order) { create(:completed_order_with_totals, user: nil, store: store) }

      it 'returns the order for guest with valid token' do
        request.headers['x-spree-token'] = guest_order.token
        get :show, params: { id: guest_order.to_param }

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(guest_order.number)
      end

      it 'returns not found with invalid token' do
        request.headers['x-spree-token'] = 'invalid'
        get :show, params: { id: guest_order.to_param }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found without token' do
        get :show, params: { id: guest_order.to_param }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'error handling' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'returns not found for invalid order id' do
        get :show, params: { id: 'or_invalid' }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found for other users order' do
        other_order = create(:completed_order_with_totals, store: store)
        get :show, params: { id: other_order.to_param }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found for incomplete orders' do
        incomplete_order = create(:order_with_line_items, user: user, store: store)
        get :show, params: { id: incomplete_order.to_param }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
