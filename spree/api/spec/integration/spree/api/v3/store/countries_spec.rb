# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Countries API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:usa) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US', name: 'United States', states_required: true) }
  let!(:california) { Spree::State.find_by(abbr: 'CA', country: usa) || create(:state, country: usa, name: 'California', abbr: 'CA') }
  let!(:new_york) { Spree::State.find_by(abbr: 'NY', country: usa) || create(:state, country: usa, name: 'New York', abbr: 'NY') }
  let!(:germany) { Spree::Country.find_by(iso: 'DE') || create(:country, iso: 'DE', name: 'Germany', states_required: false) }

  let!(:na_market) { create(:market, :default, name: 'North America', store: store, countries: [usa], currency: 'USD', default_locale: 'en', supported_locales: 'en,es') }
  let!(:eu_market) { create(:market, name: 'Europe', store: store, countries: [germany], currency: 'EUR', default_locale: 'de', supported_locales: 'de,en') }

  path '/api/v3/store/countries' do
    get 'List countries' do
      tags 'Internationalization'
      produces 'application/json'
      security [api_key: []]
      description 'Returns countries available in the store. Use ?expand=market to include market details (currency, locale, tax_inclusive).'

      sdk_example <<~JS
        const countries = await client.countries.list()
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'countries found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/Country' }
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].size).to eq(2)

          us_country = data['data'].find { |c| c['iso'] == 'US' }
          expect(us_country).to be_present
          expect(us_country['name']).to be_present
          expect(us_country['iso3']).to be_present

          de_country = data['data'].find { |c| c['iso'] == 'DE' }
          expect(de_country).to be_present
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
      description 'Returns a single country by ISO code. Supports ?expand=states for address forms and ?expand=market for market details.'

      sdk_example <<~JS
        const country = await client.countries.get('US')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :iso, in: :path, type: :string, required: true,
                description: 'Country ISO 3166-1 alpha-2 code (e.g., "US", "DE")'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'country found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:iso) { 'US' }

        schema type: :object,
               properties: {
                 iso: { type: :string },
                 iso3: { type: :string },
                 name: { type: :string },
                 states_required: { type: :boolean },
                 zipcode_required: { type: :boolean }
               },
               required: %w[iso iso3 name states_required zipcode_required]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['iso']).to eq('US')
          expect(data['name']).to be_present
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

  # Non-swagger tests for ?expand functionality
  describe 'GET /api/v3/store/countries/:iso?expand=states' do
    it 'includes states when requested' do
      get "/api/v3/store/countries/US?expand=states", headers: { 'x-spree-api-key' => api_key.token }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data['states']).to be_an(Array)
      state_abbrs = data['states'].map { |s| s['abbr'] }
      expect(state_abbrs).to match_array(['CA', 'NY'])
    end
  end

  describe 'GET /api/v3/store/countries/:iso?expand=market' do
    it 'includes market details when requested' do
      get "/api/v3/store/countries/US?expand=market", headers: { 'x-spree-api-key' => api_key.token }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data['market']).to be_present
      expect(data['market']['name']).to eq('North America')
      expect(data['market']['currency']).to eq('USD')
      expect(data['market']['default_locale']).to eq('en')
      expect(data['market']['supported_locales']).to match_array(['en', 'es'])
      expect(data['market']['tax_inclusive']).to eq(false)
    end
  end
end
