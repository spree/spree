require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::CountriesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:country) { create(:country) }
  let!(:country2) { create(:country) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #index' do
    it 'returns list of countries' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_present
      expect(json_response['data'].size).to be >= 2
    end

    it 'returns country attributes' do
      get :index

      country_data = json_response['data'].first
      expect(country_data).to include('id', 'name', 'iso')
    end

    it 'returns pagination metadata' do
      get :index

      expect(json_response['meta']).to include('page', 'count', 'pages')
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
        expect(json_response['error']['message']).to be_present
      end
    end
  end

  describe 'GET #show' do
    it 'returns the country by id' do
      get :show, params: { id: country.id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(country.id)
      expect(json_response['name']).to eq(country.name)
      expect(json_response['iso']).to eq(country.iso)
    end

    it 'includes states when available' do
      state = create(:state, country: country)
      get :show, params: { id: country.id }

      expect(response).to have_http_status(:ok)
    end

    context 'error handling' do
      it 'returns not found for non-existent country' do
        get :show, params: { id: 0 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for invalid id' do
        get :show, params: { id: 'invalid' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end
end
