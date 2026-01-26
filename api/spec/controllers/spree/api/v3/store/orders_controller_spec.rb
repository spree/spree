require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::OrdersController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'POST #create' do
    it 'creates a new cart' do
      expect {
        post :create
      }.to change(Spree::Order, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['number']).to be_present
      expect(json_response['state']).to eq('cart')
    end

    it 'creates cart associated with current store' do
      post :create

      expect(Spree::Order.last.store_id).to eq(store.id)
    end

    context 'for authenticated user' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'creates a cart associated with user' do
        post :create

        expect(response).to have_http_status(:created)
        expect(Spree::Order.last.user_id).to eq(user.id)
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        post :create

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
        expect(json_response['error']['message']).to be_present
      end
    end
  end

  describe 'GET #index' do
    let!(:order) { create(:order_with_line_items, user: user, store: store) }
    let!(:other_user_order) { create(:order_with_line_items, store: store) }

    context 'authenticated' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'returns user orders' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq(1)
        expect(json_response['data'].first['number']).to eq(order.number)
      end

      it 'does not return other users orders' do
        get :index

        numbers = json_response['data'].map { |o| o['number'] }
        expect(numbers).not_to include(other_user_order.number)
      end

      it 'returns pagination metadata' do
        get :index

        expect(json_response['meta']).to include('page', 'count', 'pages')
      end
    end

    context 'unauthenticated' do
      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
        expect(json_response['error']['message']).to be_present
      end
    end
  end

  describe 'GET #show' do
    let(:order) { create(:order_with_line_items, user: user, store: store) }

    context 'authenticated user' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'returns the order' do
        get :show, params: { id: order.number }

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(order.number)
        expect(json_response['state']).to eq(order.state)
      end

      it 'returns order with expected attributes' do
        get :show, params: { id: order.number }

        expect(json_response['id']).to eq(order.prefix_id)
        expect(json_response['number']).to eq(order.number)
      end
    end

    context 'with order token' do
      let(:guest_order) { create(:order_with_line_items, store: store) }

      it 'returns the order for guest with valid token' do
        request.headers['X-Spree-Order-Token'] = guest_order.token
        get :show, params: { id: guest_order.number }

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(guest_order.number)
      end

      it 'returns forbidden with invalid token' do
        request.headers['X-Spree-Order-Token'] = 'invalid'
        get :show, params: { id: guest_order.number }

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['code']).to eq('access_denied')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns forbidden without token' do
        get :show, params: { id: guest_order.number }

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['code']).to eq('access_denied')
      end
    end

    context 'error handling' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'returns not found for invalid order number' do
        get :show, params: { id: 'invalid' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns forbidden for other users order' do
        other_order = create(:order_with_line_items, store: store)
        get :show, params: { id: other_order.number }

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['code']).to eq('access_denied')
      end
    end
  end

  describe 'PATCH #update' do
    let(:order) { create(:order_with_line_items, user: user, store: store) }

    context 'authenticated' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'updates the order email' do
        patch :update, params: { id: order.number, order: { email: 'new@example.com' } }

        expect(response).to have_http_status(:ok)
        expect(order.reload.email).to eq('new@example.com')
      end

      it 'updates special instructions' do
        patch :update, params: { id: order.number, order: { special_instructions: 'Leave at door' } }

        expect(response).to have_http_status(:ok)
        expect(order.reload.special_instructions).to eq('Leave at door')
      end
    end

    context 'with order token' do
      let(:guest_order) { create(:order_with_line_items, store: store) }

      it 'updates order for guest with valid token' do
        request.headers['X-Spree-Order-Token'] = guest_order.token
        patch :update, params: { id: guest_order.number, order: { email: 'guest@example.com' } }

        expect(response).to have_http_status(:ok)
        expect(guest_order.reload.email).to eq('guest@example.com')
      end
    end

    context 'error handling' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'returns forbidden for other users order' do
        other_order = create(:order_with_line_items, store: store)
        patch :update, params: { id: other_order.number, order: { email: 'hack@example.com' } }

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['code']).to eq('access_denied')
        expect(json_response['error']['message']).to be_present
      end
    end
  end
end
