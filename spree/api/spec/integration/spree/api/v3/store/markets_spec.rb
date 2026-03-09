# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Markets API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:usa) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US', name: 'United States', states_required: true) }
  let!(:california) { Spree::State.find_by(abbr: 'CA', country: usa) || create(:state, country: usa, name: 'California', abbr: 'CA') }
  let!(:germany) { Spree::Country.find_by(iso: 'DE') || create(:country, iso: 'DE', name: 'Germany', states_required: false) }
  let!(:france) { Spree::Country.find_by(iso: 'FR') || create(:country, iso: 'FR', name: 'France', states_required: false) }

  let!(:na_market) { create(:market, :default, name: 'North America', store: store, countries: [usa], currency: 'USD', default_locale: 'en', supported_locales: 'en,es') }
  let!(:eu_market) { create(:market, name: 'Europe', store: store, countries: [germany, france], currency: 'EUR', default_locale: 'de', supported_locales: 'de,en,fr', tax_inclusive: true) }

  path '/api/v3/store/markets' do
    get 'List markets' do
      tags 'Markets'
      produces 'application/json'
      security [api_key: []]
      description 'Returns all markets for the current store with their countries, currency, locales, and tax configuration.'

      sdk_example <<~JS
        const markets = await client.markets.list()
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'markets found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: { type: :array }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].size).to eq(2)

          na = data['data'].find { |m| m['name'] == 'North America' }
          expect(na['currency']).to eq('USD')
          expect(na['default_locale']).to eq('en')
          expect(na['supported_locales']).to match_array(['en', 'es'])
          expect(na['tax_inclusive']).to eq(false)
          expect(na['default']).to eq(true)
          expect(na['countries'].size).to eq(1)
          expect(na['countries'].first['iso']).to eq('US')

          eu = data['data'].find { |m| m['name'] == 'Europe' }
          expect(eu['currency']).to eq('EUR')
          expect(eu['tax_inclusive']).to eq(true)
          expect(eu['default']).to eq(false)
          expect(eu['countries'].size).to eq(2)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/markets/{id}' do
    get 'Get a market' do
      tags 'Markets'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a single market by prefixed ID with its countries, currency, locales, and tax configuration.'

      sdk_example <<~JS
        const market = await client.markets.get('mkt_xxx')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Market prefixed ID (e.g., "mkt_k5nR8xLq")'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'market found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { eu_market.prefixed_id }

        schema type: :object

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(eu_market.prefixed_id)
          expect(data['name']).to eq('Europe')
          expect(data['currency']).to eq('EUR')
          expect(data['tax_inclusive']).to eq(true)
          expect(data['countries'].size).to eq(2)
        end
      end

      response '404', 'market not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { 'mkt_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/markets/resolve' do
    get 'Resolve market by country' do
      tags 'Markets'
      produces 'application/json'
      security [api_key: []]
      description 'Determine which market applies for a given country ISO code. Useful for auto-selecting the correct currency and locale when a customer\'s location is known.'

      sdk_example <<~JS
        const market = await client.markets.resolve('DE')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :country, in: :query, type: :string, required: true,
                description: 'Country ISO 3166-1 alpha-2 code (e.g., "DE", "US")'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'market resolved' do
        let(:'x-spree-api-key') { api_key.token }
        let(:country) { 'DE' }

        schema type: :object

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(eu_market.prefixed_id)
          expect(data['name']).to eq('Europe')
          expect(data['currency']).to eq('EUR')
          expect(data['tax_inclusive']).to eq(true)
        end
      end

      response '404', 'no market for country' do
        let(:'x-spree-api-key') { api_key.token }
        let(:country) { 'JP' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/markets/{market_id}/countries' do
    get 'List countries in a market' do
      tags 'Markets'
      produces 'application/json'
      security [api_key: []]
      description 'Returns countries belonging to a specific market. Use this for address form country dropdowns during checkout.'

      sdk_example <<~JS
        const countries = await client.markets.countries.list('mkt_xxx')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :market_id, in: :path, type: :string, required: true,
                description: 'Market prefixed ID'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'countries found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:market_id) { eu_market.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].size).to eq(2)
          isos = data['data'].map { |c| c['iso'] }
          expect(isos).to match_array(['DE', 'FR'])
        end
      end
    end
  end

  path '/api/v3/store/markets/{market_id}/countries/{id}' do
    get 'Get a country in a market' do
      tags 'Markets'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a single country by ISO code within a market. Supports ?expand=states for address forms.'

      sdk_example <<~JS
        const country = await client.markets.countries.get('mkt_xxx', 'DE')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :market_id, in: :path, type: :string, required: true,
                description: 'Market prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Country ISO 3166-1 alpha-2 code (e.g., "DE")'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'country found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:market_id) { na_market.prefixed_id }
        let(:id) { 'US' }

        schema type: :object

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['iso']).to eq('US')
          expect(data['states_required']).to eq(true)
        end
      end

      response '404', 'country not in market' do
        let(:'x-spree-api-key') { api_key.token }
        let(:market_id) { eu_market.prefixed_id }
        let(:id) { 'US' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
