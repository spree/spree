require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Catalogs::OrderMinimumsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:catalog) { create(:catalog, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the minimums with their formatted amount' do
      create(:catalog_order_minimum, catalog: catalog, currency: 'USD', amount: 500)

      get :index, params: { catalog_id: catalog.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['currency']).to eq('USD')
      expect(row['amount']).to eq('500.0')
      expect(row['display_amount']).to include('500')
    end
  end

  describe 'POST #create' do
    it 'records a minimum for a currency' do
      post :create, params: { catalog_id: catalog.prefixed_id, currency: 'EUR', amount: '450.00' }, as: :json

      expect(response).to have_http_status(:created)
      expect(catalog.order_minimums.reload.first.currency).to eq('EUR')
    end

    it 'refuses a second row for the same currency' do
      create(:catalog_order_minimum, catalog: catalog, currency: 'USD')

      post :create, params: { catalog_id: catalog.prefixed_id, currency: 'USD', amount: '100' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    it 'lifts the minimum' do
      minimum = create(:catalog_order_minimum, catalog: catalog)

      delete :destroy, params: { catalog_id: catalog.prefixed_id, id: minimum.prefixed_id }, as: :json

      expect(catalog.order_minimums.reload).to be_empty
    end
  end

  describe 'PUT #replace' do
    it 'writes the whole set in one request' do
      put :replace, params: {
        catalog_id: catalog.prefixed_id,
        order_minimums: [{ currency: 'USD', amount: '500' }, { currency: 'EUR', amount: '450' }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(catalog.order_minimums.reload.pluck(:currency)).to match_array(%w[USD EUR])
    end

    # The set arrives whole, so a currency left out is one the merchant
    # deleted on a page that stages every term behind its Save.
    it 'lifts a minimum the payload leaves out' do
      create(:catalog_order_minimum, catalog: catalog, currency: 'USD')
      create(:catalog_order_minimum, catalog: catalog, currency: 'EUR')

      put :replace, params: {
        catalog_id: catalog.prefixed_id,
        order_minimums: [{ currency: 'USD', amount: '500' }]
      }, as: :json

      expect(catalog.order_minimums.reload.pluck(:currency)).to eq(['USD'])
    end

    it 'refuses the whole set when one amount is unusable' do
      put :replace, params: {
        catalog_id: catalog.prefixed_id,
        order_minimums: [{ currency: 'USD', amount: '500' }, { currency: 'EUR', amount: '0' }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(catalog.order_minimums.reload).to be_empty
    end
  end

  describe 'a catalog in another store' do
    it 'is not found' do
      foreign = create(:catalog, store: create(:store))

      get :index, params: { catalog_id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
