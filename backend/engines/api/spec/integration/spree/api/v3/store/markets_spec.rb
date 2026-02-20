# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Markets API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:usa) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US', name: 'United States') }
  let!(:germany) { Spree::Country.find_by(iso: 'DE') || create(:country, iso: 'DE', name: 'Germany') }

  let(:na_zone) do
    zone = create(:zone, name: 'North America', kind: :country)
    zone.zone_members.create!(zoneable: usa)
    zone
  end
  let(:eu_zone) do
    zone = create(:zone, name: 'Europe', kind: :country)
    zone.zone_members.create!(zoneable: germany)
    zone
  end

  let!(:na_market) { create(:market, :default, name: 'North America', store: store, zone: na_zone, currency: 'USD', default_locale: 'en') }
  let!(:eu_market) { create(:market, name: 'Europe', store: store, zone: eu_zone, currency: 'EUR', default_locale: 'de') }

  path '/api/v3/store/markets' do
    get 'List all markets' do
      tags 'Markets'
      produces 'application/json'
      security [api_key: []]
      description 'Returns all markets for the store with their countries. Used to build country/currency switcher.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true

      response '200', 'markets found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/StoreMarket' }
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].size).to eq(2)
          market_names = data['data'].map { |m| m['name'] }
          expect(market_names).to include('North America', 'Europe')
          na = data['data'].find { |m| m['name'] == 'North America' }
          expect(na['currency']).to eq('USD')
          expect(na['countries']).to be_an(Array)
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
      description 'Returns a single market by prefixed ID with its countries'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Market prefixed ID (e.g., "mkt_abc123")'

      response '200', 'market found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { na_market.prefixed_id }

        schema '$ref' => '#/components/schemas/StoreMarket'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('North America')
          expect(data['currency']).to eq('USD')
          expect(data['default_locale']).to eq('en')
          expect(data['countries']).to be_an(Array)
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
    get 'Resolve market for a country' do
      tags 'Markets'
      produces 'application/json'
      security [api_key: []]
      description 'Resolves which market a country belongs to. Used when customer selects a country.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :country, in: :query, type: :string, required: true,
                description: 'ISO 3166-1 alpha-2 country code (e.g., "US", "DE")'

      response '200', 'market resolved' do
        let(:'x-spree-api-key') { api_key.token }
        let(:country) { 'DE' }

        schema '$ref' => '#/components/schemas/StoreMarket'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Europe')
          expect(data['currency']).to eq('EUR')
        end
      end

      response '400', 'missing country parameter' do
        let(:'x-spree-api-key') { api_key.token }
        let(:country) { '' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'country not found or no market' do
        let(:'x-spree-api-key') { api_key.token }
        let(:country) { 'XX' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
