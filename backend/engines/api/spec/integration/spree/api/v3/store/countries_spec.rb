# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Markets Countries API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:usa) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US', name: 'United States', states_required: true) }
  let!(:california) { Spree::State.find_by(abbr: 'CA', country: usa) || create(:state, country: usa, name: 'California', abbr: 'CA') }
  let!(:new_york) { Spree::State.find_by(abbr: 'NY', country: usa) || create(:state, country: usa, name: 'New York', abbr: 'NY') }
  let!(:germany) { Spree::Country.find_by(iso: 'DE') || create(:country, iso: 'DE', name: 'Germany', states_required: false) }

  let!(:market) { create(:market, :default, store: store, countries: [usa, germany]) }
  let(:market_id) { market.prefixed_id }

  path '/api/v3/store/markets/{market_id}/countries' do
    get 'List countries in a market' do
      tags 'Countries'
      produces 'application/json'
      security [api_key: []]
      description 'Returns countries available in the market (for checkout address dropdown)'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :market_id, in: :path, type: :string, required: true,
                description: 'Market prefixed ID (e.g., "mkt_abc123")'

      response '200', 'countries found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       iso: { type: :string, description: 'ISO 3166-1 alpha-2 code' },
                       iso3: { type: :string, description: 'ISO 3166-1 alpha-3 code' },
                       name: { type: :string },
                       states_required: { type: :boolean },
                       zipcode_required: { type: :boolean }
                     },
                     required: %w[iso iso3 name states_required zipcode_required]
                   }
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          us_country = data['data'].find { |c| c['iso'] == 'US' }
          expect(us_country).to be_present
          expect(us_country['name']).to be_present
          expect(us_country).not_to have_key('states')
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/markets/{market_id}/countries/{iso}' do
    get 'Get a country with states' do
      tags 'Countries'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a single country by ISO code with its states (for address form validation)'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :market_id, in: :path, type: :string, required: true,
                description: 'Market prefixed ID (e.g., "mkt_abc123")'
      parameter name: :iso, in: :path, type: :string, required: true,
                description: 'Country ISO 3166-1 alpha-2 code (e.g., "US", "DE", "CA")'

      response '200', 'country found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:iso) { 'US' }

        schema type: :object,
               properties: {
                 iso: { type: :string, description: 'ISO 3166-1 alpha-2 code' },
                 iso3: { type: :string, description: 'ISO 3166-1 alpha-3 code' },
                 name: { type: :string },
                 states_required: { type: :boolean },
                 zipcode_required: { type: :boolean },
                 states: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       abbr: { type: :string, description: 'State abbreviation code' },
                       name: { type: :string }
                     },
                     required: %w[abbr name]
                   }
                 }
               },
               required: %w[iso iso3 name states_required zipcode_required states]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['iso']).to eq('US')
          expect(data['states']).to be_an(Array)
          state_abbrs = data['states'].map { |s| s['abbr'] }
          expect(state_abbrs).to include('CA', 'NY')
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
end
