# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Currencies API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:usa) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US', name: 'United States') }
  let!(:germany) { Spree::Country.find_by(iso: 'DE') || create(:country, iso: 'DE', name: 'Germany') }

  let!(:na_market) { create(:market, :default, name: 'North America', store: store, countries: [usa], currency: 'USD', default_locale: 'en') }
  let!(:eu_market) { create(:market, name: 'Europe', store: store, countries: [germany], currency: 'EUR', default_locale: 'de') }

  path '/api/v3/store/currencies' do
    get 'List supported currencies' do
      tags 'Currencies'
      produces 'application/json'
      security [api_key: []]
      description 'Returns currencies supported by the store (derived from markets)'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true

      response '200', 'currencies found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/StoreCurrency' }
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          iso_codes = data['data'].map { |c| c['iso_code'] }
          expect(iso_codes).to include('USD', 'EUR')

          usd = data['data'].find { |c| c['iso_code'] == 'USD' }
          expect(usd['name']).to be_present
          expect(usd['symbol']).to be_present
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
