# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Locales API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:usa) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US', name: 'United States') }
  let!(:germany) { Spree::Country.find_by(iso: 'DE') || create(:country, iso: 'DE', name: 'Germany') }

  let!(:na_market) { create(:market, :default, name: 'North America', store: store, countries: [usa], currency: 'USD', default_locale: 'en') }
  let!(:eu_market) { create(:market, name: 'Europe', store: store, countries: [germany], currency: 'EUR', default_locale: 'de') }

  path '/api/v3/store/locales' do
    get 'List supported locales' do
      tags 'Internationalization'
      produces 'application/json'
      security [api_key: []]
      description 'Returns locales supported by the store (derived from markets)'

      sdk_example <<~JS
        const locales = await client.store.locales.list()
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true

      response '200', 'locales found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/StoreLocale' }
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          codes = data['data'].map { |l| l['code'] }
          expect(codes).to include('en', 'de')

          data['data'].each do |locale|
            expect(locale['code']).to be_present
            expect(locale['name']).to be_present
          end
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
