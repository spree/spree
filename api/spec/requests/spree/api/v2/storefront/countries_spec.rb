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
