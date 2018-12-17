require 'spec_helper'
require 'shared_examples/api_v2/base'

describe 'Storefront API v2 Countries spec', type: :request do
  let!(:country) { create(:country) }
  let!(:states)    { create_list(:state, 2, country: country) }
  let!(:default_country) do
    country = create(:country, iso3: 'GBR')
    Spree::Config[:default_country_id] = country.id
    country
  end

  shared_examples 'returns valid country resource JSON' do
    it 'returns a valid country resource JSON response' do
      expect(response.status).to eq(200)

      expect(json_response['data']).to have_type('country')
      expect(json_response['data']).to have_relationships(:states)

      expect(json_response['data']).to have_attribute(:iso)
      expect(json_response['data']).to have_attribute(:iso3)
      expect(json_response['data']).to have_attribute(:iso_name)
      expect(json_response['data']).to have_attribute(:name)
      expect(json_response['data']).to have_attribute(:default)
      expect(json_response['data']).to have_attribute(:states_required)
      expect(json_response['data']).to have_attribute(:zipcode_required)
    end
  end

  describe 'countries#index' do
    context 'with no params' do
      before { get '/api/v2/storefront/countries' }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns all countries' do
        expect(json_response['data'].size).to eq(2)
        expect(json_response['data'][0]).to have_type('country')
        expect(json_response['data'][0]).to have_relationships(:states)
      end
    end

    context 'paginate countries' do
      context 'with specified pagination params' do
        before { get '/api/v2/storefront/countries?page=1&per_page=1' }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns specified amount of countries' do
          expect(json_response['data'].count).to eq 1
        end

        it 'returns proper meta data' do
          expect(json_response['meta']['count']).to       eq 1
          expect(json_response['meta']['total_count']).to eq Spree::Country.count
        end

        it 'returns proper links data' do
          expect(json_response['links']['self']).to include('/api/v2/storefront/countries?page=1&per_page=1')
          expect(json_response['links']['next']).to include('/api/v2/storefront/countries?page=2&per_page=1')
          expect(json_response['links']['prev']).to include('/api/v2/storefront/countries?page=1&per_page=1')
        end
      end

      context 'without specified pagination params' do
        before { get '/api/v2/storefront/countries' }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns specified amount of countries' do
          expect(json_response['data'].count).to eq Spree::Country.count
        end

        it 'returns proper meta data' do
          expect(json_response['meta']['count']).to       eq json_response['data'].count
          expect(json_response['meta']['total_count']).to eq Spree::Country.count
        end

        it 'returns proper links data' do
          expect(json_response['links']['self']).to include('/api/v2/storefront/countries')
          expect(json_response['links']['next']).to include('/api/v2/storefront/countries?page=1')
          expect(json_response['links']['prev']).to include('/api/v2/storefront/countries?page=1')
        end
      end
    end

    context 'with specified options' do
      before { get '/api/v2/storefront/countries?include=states' }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns country with included states' do
        expect(json_response['data'].first).to have_id(country.id.to_s)
        expect(json_response['included']).to   include(have_type('state').and(have_attribute(:abbr).with_value(states.first.abbr)))
        expect(json_response['included']).to   include(have_type('state').and(have_attribute(:name).with_value(states.first.name)))
      end
    end
  end

  describe 'country#show' do
    context 'by iso' do
      before do
        get "/api/v2/storefront/countries/#{country.iso}"
      end

      it_behaves_like 'returns valid country resource JSON'

      it 'returns country by iso' do
        expect(json_response['data']).to have_id(country.id.to_s)
        expect(json_response['data']).to have_attribute(:iso).with_value(country.iso)
        expect(json_response['data']).to have_attribute(:iso3).with_value(country.iso3)
        expect(json_response['data']).to have_attribute(:iso_name).with_value(country.iso_name)
        expect(json_response['data']).to have_attribute(:name).with_value(country.name)
        expect(json_response['data']).to have_attribute(:default).with_value(country == Spree::Country.default)
        expect(json_response['data']).to have_attribute(:states_required).with_value(country.states_required)
        expect(json_response['data']).to have_attribute(:zipcode_required).with_value(country.zipcode_required)
      end
    end

    context 'by iso3' do
      before do
        get "/api/v2/storefront/countries/#{country.iso3}"
      end

      it_behaves_like 'returns valid country resource JSON'

      it 'returns country by iso3' do
        expect(json_response['data']).to have_id(country.id.to_s)
        expect(json_response['data']).to have_attribute(:iso3).with_value(country.iso3)
      end
    end

    context 'by "default"' do
      before do
        get "/api/v2/storefront/countries/default"
      end

      it_behaves_like 'returns valid country resource JSON'

      it 'returns default country' do
        expect(json_response['data']).to have_id(default_country.id.to_s)
        expect(json_response['data']).to have_attribute(:iso).with_value(default_country.iso)
        expect(json_response['data']).to have_attribute(:default).with_value(true)
      end
    end

    context 'with specified options' do
      before { get "/api/v2/storefront/countries/#{country.iso}?include=states" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns country with included states' do
        expect(json_response['data']).to have_id(country.id.to_s)
        expect(json_response['included']).to   include(have_type('state').and(have_attribute(:abbr).with_value(states.first.abbr)))
        expect(json_response['included']).to   include(have_type('state').and(have_attribute(:name).with_value(states.first.name)))
      end
    end
  end
end
