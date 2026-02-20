require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::MarketsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:country) { create(:country) }
  let!(:market) { create(:market, :default, store: store, countries: [country], name: 'North America', currency: 'USD') }

  before do
    request.headers['x-spree-api-key'] = api_key.token
  end

  describe 'GET #index' do
    it 'returns list of markets' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(1)
    end

    it 'returns market attributes with countries' do
      get :index

      market_data = json_response['data'].first
      expect(market_data['id']).to eq(market.prefixed_id)
      expect(market_data['name']).to eq('North America')
      expect(market_data['currency']).to eq('USD')
      expect(market_data['default_locale']).to eq('en')
      expect(market_data['supported_locales']).to eq(['en'])
      expect(market_data['default']).to be true
      expect(market_data['countries']).to be_an(Array)
    end

    context 'without API key' do
      before { request.headers['x-spree-api-key'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    it 'returns the market' do
      get :show, params: { id: market.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(market.prefixed_id)
      expect(json_response['name']).to eq('North America')
      expect(json_response['countries']).to be_an(Array)
    end

    it 'returns not found for non-existent market' do
      get :show, params: { id: 'mkt_nonexistent' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #resolve' do
    it 'resolves country to market' do
      get :resolve, params: { country: country.iso }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(market.prefixed_id)
    end

    it 'returns not found for country not in any market' do
      other_country = create(:country)
      get :resolve, params: { country: other_country.iso }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns bad request without country param' do
      get :resolve, params: {}

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns not found for invalid country ISO' do
      get :resolve, params: { country: 'XX' }

      expect(response).to have_http_status(:not_found)
    end
  end
end
