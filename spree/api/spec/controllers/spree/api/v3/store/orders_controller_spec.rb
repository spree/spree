require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::OrdersController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #show' do
    let(:order) { create(:completed_order_with_totals, customer: user, store: store) }

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

    context 'with the cart handle after completion' do
      let(:cart) { create(:cart_with_line_items, store: store) }
      let!(:completed_order) do
        create(:completed_order_with_totals, customer: nil, store: store, cart_id: cart.id, token: cart.token)
      end

      before { cart.update_columns(completed_at: Time.current) }

      # The storefront keeps the cart id through checkout; after completion
      # the same handle + cart token must resolve the resulting order.
      it 'resolves the order created from that cart' do
        request.headers['x-spree-token'] = cart.token

        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(completed_order.prefixed_id)
        expect(json_response['number']).to eq(completed_order.number)
      end

      it 'returns not found without the matching token' do
        request.headers['x-spree-token'] = 'wrong-token'

        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with spree token' do
      let(:guest_order) { create(:completed_order_with_totals, customer: nil, store: store) }

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
        incomplete_order = create(:order_with_line_items, customer: user, store: store)
        get :show, params: { id: incomplete_order.to_param }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
