# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Countries API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:usa) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US', name: 'United States', states_required: true) }
  let!(:california) { Spree::State.find_by(abbr: 'CA', country: usa) || create(:state, country: usa, name: 'California', abbr: 'CA') }
  let!(:new_york) { Spree::State.find_by(abbr: 'NY', country: usa) || create(:state, country: usa, name: 'New York', abbr: 'NY') }
  let!(:germany) { Spree::Country.find_by(iso: 'DE') || create(:country, iso: 'DE', name: 'Germany', states_required: false) }

  let!(:na_market) { create(:market, :default, name: 'North America', store: store, countries: [usa], currency: 'USD', default_locale: 'en') }
  let!(:eu_market) { create(:market, name: 'Europe', store: store, countries: [germany], currency: 'EUR', default_locale: 'de') }

  path '/api/v3/store/countries' do
    get 'List countries' do
      tags 'Internationalization'
      produces 'application/json'
      security [api_key: []]
      description 'Returns countries available in the store with their currency and locale (derived from markets)'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true

      response '200', 'countries found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/StoreCountry' }
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].size).to eq(2)

          us_country = data['data'].find { |c| c['iso'] == 'US' }
          expect(us_country).to be_present
          expect(us_country['name']).to be_present
          expect(us_country['currency']).to eq('USD')
          expect(us_country['default_locale']).to eq('en')

          de_country = data['data'].find { |c| c['iso'] == 'DE' }
          expect(de_country).to be_present
          expect(de_country['currency']).to eq('EUR')
          expect(de_country['default_locale']).to eq('de')
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/countries/{iso}' do
    get 'Get a country' do
      tags 'Internationalization'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a single country by ISO code with currency and locale. Supports ?include=states for address forms.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :iso, in: :path, type: :string, required: true,
                description: 'Country ISO 3166-1 alpha-2 code (e.g., "US", "DE")'

      response '200', 'country found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:iso) { 'US' }

        schema type: :object,
               properties: {
                 iso: { type: :string },
                 iso3: { type: :string },
                 name: { type: :string },
                 states_required: { type: :boolean },
                 zipcode_required: { type: :boolean },
                 currency: { type: :string, nullable: true },
                 default_locale: { type: :string, nullable: true },
                 states: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       abbr: { type: :string },
                       name: { type: :string }
                     },
                     required: %w[abbr name]
                   }
                 }
               },
               required: %w[iso iso3 name states_required zipcode_required]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['iso']).to eq('US')
          expect(data['currency']).to eq('USD')
          expect(data['default_locale']).to eq('en')
        end
      end

      response '404', 'country not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:iso) { 'XX' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  # Non-swagger test for ?include=states functionality
  describe 'GET /api/v3/store/countries/:iso?include=states' do
    it 'includes states when requested' do
      get "/api/v3/store/countries/US?include=states", headers: { 'x-spree-api-key' => api_key.token }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data['states']).to be_an(Array)
      state_abbrs = data['states'].map { |s| s['abbr'] }
      expect(state_abbrs).to match_array(['CA', 'NY'])
    end
  end
end
