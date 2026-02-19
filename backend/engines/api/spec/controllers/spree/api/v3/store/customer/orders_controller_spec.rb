require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::OrdersController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:order) { create(:order_with_line_items, user: user, store: store) }
  let!(:other_user_order) { create(:order_with_line_items, store: store) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
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

    it 'does not return orders from other stores' do
      other_store = create(:store)
      create(:order_with_line_items, user: user, store: other_store)

      get :index

      numbers = json_response['data'].map { |o| o['number'] }
      expect(numbers).to eq([order.number])
    end

    it 'returns pagination metadata' do
      get :index

      expect(json_response['meta']).to include('page', 'count', 'pages')
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end
  end
end
