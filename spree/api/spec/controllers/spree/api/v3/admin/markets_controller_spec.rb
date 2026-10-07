require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::MarketsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:market) { create(:market, store: store) }
  let!(:other_store_market) { create(:market, store: create(:store)) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns markets in the current store only' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |m| m['id'] }
      expect(ids).to include(market.prefixed_id)
      expect(ids).not_to include(other_store_market.prefixed_id)
    end

    it 'returns markets in list order' do
      market.update!(name: 'Anchor market')
      second = create(:market, store: store, name: 'Second market')
      third = create(:market, store: store, name: 'Third market')
      third.insert_at(1)
      market.insert_at(2)

      get :index, as: :json

      rows = json_response['data'].select do |row|
        [third, market, second].map(&:prefixed_id).include?(row['id'])
      end
      expect(rows.pluck('name')).to eq(['Third market', 'Anchor market', 'Second market'])
    end
  end

  describe 'GET #show' do
    it 'returns the market' do
      get :show, params: { id: market.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(market.prefixed_id)
      expect(json_response['name']).to eq(market.name)
    end

    it '404s on a market from another store' do
      get :show, params: { id: other_store_market.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'reports which tax engine computes for the market' do
      get :show, params: { id: market.prefixed_id }, as: :json

      # Nil means the store-wide default.
      expect(json_response).to have_key('tax_provider')
      expect(json_response['tax_provider']).to be_nil
    end
  end

  describe 'PATCH #update' do
    it 'points the market at an installed tax engine' do
      patch :update, params: { id: market.prefixed_id, tax_provider: 'internal' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['tax_provider']).to eq('internal')
      expect(market.reload.tax_provider).to eq('Spree::TaxProvider::Internal')
      expect(market.tax_provider_instance).to be_a(Spree::TaxProvider::Internal)
    end

    it 'refuses an engine this installation does not have' do
      patch :update, params: { id: market.prefixed_id, tax_provider: 'imaginary' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(market.reload.tax_provider).to be_nil
    end

    it 'clears the selection back to the store default' do
      market.update_columns(tax_provider: 'Spree::TaxProvider::Internal')

      patch :update, params: { id: market.prefixed_id, tax_provider: '' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(market.reload.tax_provider).to be_blank
    end

    it 'names the main country among its own countries in the same request' do
      patch :update, params: { id: market.prefixed_id, country_codes: %w[DE FR], default_country_code: 'de' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['default_country_code']).to eq('DE')
      expect(market.reload.default_country.iso).to eq('DE')
    end

    it "refuses a main country outside the market's countries" do
      patch :update, params: { id: market.prefixed_id, default_country_code: 'JP' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response.dig('error', 'details', 'default_country_code')).to be_present
      expect(market.reload.default_country_code).to be_nil
    end
  end
end
