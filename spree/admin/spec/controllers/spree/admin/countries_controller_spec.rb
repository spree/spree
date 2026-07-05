require 'spec_helper'

RSpec.describe Spree::Admin::CountriesController, type: :controller do
  stub_authorization!

  render_views

  describe 'GET #select_options' do
    let!(:poland) { create(:country, name: 'Poland', iso: 'PL') }
    let!(:germany) { create(:country, name: 'Germany', iso: 'DE') }
    let!(:france) { create(:country, name: 'France', iso: 'FR') }

    it 'returns all countries with an English value and a localized label' do
      get :select_options, format: :json

      json = JSON.parse(response.body)
      france = json.find { |c| c['name'] == 'France' }
      expect(france).to be_present
      expect(france['label']).to include('France').and include('🇫🇷')
    end

    it 'sorts countries by localized name' do
      get :select_options, format: :json

      json = JSON.parse(response.body)
      # Labels carry a leading flag emoji whose codepoints sort by ISO code, not
      # by name — assert ordering on the name portion (after the flag prefix).
      country_names = json.map { |c| c['label'].split(' ', 2).last }
      expect(country_names).to eq(country_names.sort)
    end

    it 'returns the full list regardless of query (filtering is client-side)' do
      get :select_options, params: { q: 'pol' }, format: :json

      json = JSON.parse(response.body)
      names = json.map { |c| c['name'] }
      expect(names).to include('France', 'Germany', 'Poland')
    end
  end
end
