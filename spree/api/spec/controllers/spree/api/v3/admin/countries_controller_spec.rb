require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CountriesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    subject { get :index, as: :json }

    it 'returns countries' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].length).to be > 0
    end

    it 'returns ALL countries without pagination truncation' do
      subject
      total_countries = Spree::Country.count
      expect(json_response['data'].length).to eq(total_countries)
      expect(json_response['meta']['count']).to eq(total_countries)
    end

    it 'returns countries ordered by name' do
      subject
      names = json_response['data'].map { |c| c['name'] }
      expect(names).to eq(names.sort)
    end

    it 'includes iso and name fields' do
      subject
      country = json_response['data'].first
      expect(country['iso']).to be_present
      expect(country['name']).to be_present
    end

    context 'with expand=states' do
      subject { get :index, params: { expand: 'states' }, as: :json }

      let!(:country_with_states) do
        country = Spree::Country.first || create(:country)
        create(:state, country: country) unless country.states.any?
        country
      end

      it 'includes nested states' do
        subject
        country_data = json_response['data'].find { |c| c['iso'] == country_with_states.iso }
        expect(country_data['states']).to be_an(Array)
        expect(country_data['states'].first['abbr']).to be_present
        expect(country_data['states'].first['name']).to be_present
      end
    end

    context 'without authentication' do
      let(:headers) { {} }

      it 'returns unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    let!(:country) { Spree::Country.first || create(:country) }

    subject { get :show, params: { id: country.iso }, as: :json }

    it 'returns the country by ISO code' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['iso']).to eq(country.iso)
      expect(json_response['name']).to eq(country.name)
    end

    it 'accepts lowercase ISO code' do
      get :show, params: { id: country.iso.downcase }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['iso']).to eq(country.iso)
    end

    context 'with expand=states' do
      before { create(:state, country: country) unless country.states.any? }

      it 'includes nested states' do
        get :show, params: { id: country.iso, expand: 'states' }, as: :json
        expect(response).to have_http_status(:ok)
        expect(json_response['states']).to be_an(Array)
        expect(json_response['states']).not_to be_empty
      end
    end

    context 'with invalid ISO code' do
      it 'returns not found' do
        get :show, params: { id: 'ZZ' }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
