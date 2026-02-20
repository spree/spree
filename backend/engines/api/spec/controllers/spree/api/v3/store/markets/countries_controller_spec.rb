require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Markets::CountriesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:country) { create(:country) }
  let(:zone) { create(:zone, kind: :country) }
  let!(:market) { create(:market, store: store, zone: zone) }

  before do
    zone.zone_members.create!(zoneable: country)
    request.headers['x-spree-api-key'] = api_key.token
  end

  describe 'GET #index' do
    it 'returns countries from the market zone' do
      get :index, params: { market_id: market.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(1)
      expect(json_response['data'].first['iso']).to eq(country.iso)
    end

    it 'does not include states by default' do
      create(:state, country: country)
      get :index, params: { market_id: market.prefixed_id }

      expect(json_response['data'].first).not_to have_key('states')
    end
  end

  describe 'GET #show' do
    it 'returns country with states' do
      state = create(:state, country: country)
      get :show, params: { market_id: market.prefixed_id, id: country.iso }

      expect(response).to have_http_status(:ok)
      expect(json_response['iso']).to eq(country.iso)
      expect(json_response['states']).to be_present
      expect(json_response['states'].first['abbr']).to eq(state.abbr)
    end

    it 'returns not found for country not in market' do
      other_country = create(:country)
      get :show, params: { market_id: market.prefixed_id, id: other_country.iso }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for invalid market' do
      get :show, params: { market_id: 'mkt_nonexistent', id: country.iso }

      expect(response).to have_http_status(:not_found)
    end
  end
end
