require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::StoreCreditsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:store_credit) { create(:store_credit, user: user, store: store, currency: 'USD', amount: 50) }
  let!(:other_currency_credit) { create(:store_credit, user: user, store: store, currency: 'EUR', amount: 25) }
  let!(:other_store_credit) { create(:store_credit, user: create(:user), store: store, currency: 'USD', amount: 100) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
    it 'returns store credits for the current user, store and currency' do
      get :index

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |sc| sc['id'] }
      expect(ids).to include(store_credit.prefixed_id)
      expect(ids).not_to include(other_currency_credit.prefixed_id)
      expect(ids).not_to include(other_store_credit.prefixed_id)
    end

    it 'returns store credit attributes' do
      get :index

      credit = json_response['data'].first
      expect(credit).to include('id', 'amount', 'amount_used', 'amount_remaining', 'currency')
      expect(credit).to include('display_amount', 'display_amount_used', 'display_amount_remaining')
    end

    it 'supports pagination' do
      get :index, params: { page: 1, limit: 1 }

      expect(response).to have_http_status(:ok)
      expect(json_response['meta']).to include('page', 'count')
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    it 'returns the store credit' do
      get :show, params: { id: store_credit.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(store_credit.prefixed_id)
      expect(json_response['amount']).to be_present
    end

    it 'returns not found for other user store credit' do
      get :show, params: { id: other_store_credit.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for other currency store credit' do
      get :show, params: { id: other_currency_credit.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :show, params: { id: store_credit.prefixed_id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
