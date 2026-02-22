require 'spec_helper'

RSpec.describe Spree::Admin::CountriesController, type: :controller do
  stub_authorization!

  render_views

  describe 'GET #select_options' do
    let!(:poland) { create(:country, name: 'Poland', iso: 'PL') }
    let!(:germany) { create(:country, name: 'Germany', iso: 'DE') }
    let!(:france) { create(:country, name: 'France', iso: 'FR') }

    it 'returns countries ordered by name' do
      get :select_options, format: :json

      json = JSON.parse(response.body)
      names = json.map { |c| c['name'] }
      expect(names).to include('France', 'Germany', 'Poland')
      expect(names).to eq(names.sort)
    end

    it 'filters countries by query string' do
      get :select_options, params: { q: 'pol' }, format: :json

      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first['name']).to eq('Poland')
    end

    it 'filters countries by ransack hash' do
      get :select_options, params: { q: { name_cont: 'pol' } }, format: :json

      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first['name']).to eq('Poland')
    end

    it 'returns empty array when no matches' do
      get :select_options, params: { q: 'xyz' }, format: :json

      json = JSON.parse(response.body)
      expect(json).to be_empty
    end

    it 'is case insensitive' do
      get :select_options, params: { q: 'GERMANY' }, format: :json

      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first['name']).to eq('Germany')
    end
  end
end
