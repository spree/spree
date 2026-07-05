require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::MarketsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:usa) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US', name: 'United States') }
  let!(:germany) { Spree::Country.find_by(iso: 'DE') || create(:country, iso: 'DE', name: 'Germany') }
  let!(:france) { Spree::Country.find_by(iso: 'FR') || create(:country, iso: 'FR', name: 'France') }

  let!(:na_market) { create(:market, :default, name: 'North America', store: store, countries: [usa], currency: 'USD', default_locale: 'en', supported_locales: 'en,es') }
  let!(:eu_market) { create(:market, name: 'Europe', store: store, countries: [germany, france], currency: 'EUR', default_locale: 'de', supported_locales: 'de,en,fr', tax_inclusive: true) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #index' do
    it 'returns all markets for the store' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(2)
    end

    it 'returns market attributes' do
      get :index

      na = json_response['data'].find { |m| m['name'] == 'North America' }
      expect(na['id']).to eq(na_market.prefixed_id)
      expect(na['currency']).to eq('USD')
      expect(na['default_locale']).to eq('en')
      expect(na['supported_locales']).to match_array(['en', 'es'])
      expect(na['tax_inclusive']).to eq(false)
      expect(na['default']).to eq(true)
    end

    it 'includes nested countries' do
      get :index

      eu = json_response['data'].find { |m| m['name'] == 'Europe' }
      expect(eu['countries'].size).to eq(2)
      isos = eu['countries'].map { |c| c['iso'] }
      expect(isos).to match_array(['DE', 'FR'])
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    it 'returns a market by prefixed ID' do
      get :show, params: { id: eu_market.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(eu_market.prefixed_id)
      expect(json_response['name']).to eq('Europe')
      expect(json_response['currency']).to eq('EUR')
      expect(json_response['tax_inclusive']).to eq(true)
      expect(json_response['countries'].size).to eq(2)
    end

    it 'returns 404 for non-existent market' do
      get :show, params: { id: 'mkt_nonexistent' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #resolve' do
    it 'resolves a market by country ISO' do
      get :resolve, params: { country: 'DE' }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(eu_market.prefixed_id)
      expect(json_response['name']).to eq('Europe')
      expect(json_response['currency']).to eq('EUR')
    end

    it 'is case-insensitive for country ISO' do
      get :resolve, params: { country: 'de' }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(eu_market.prefixed_id)
    end

    it 'returns 404 for a country not in any market' do
      create(:country, iso: 'JP', name: 'Japan')
      get :resolve, params: { country: 'JP' }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for an invalid country ISO' do
      get :resolve, params: { country: 'XX' }

      expect(response).to have_http_status(:not_found)
    end
  end
end
