# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Store API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  path '/api/v3/store/store' do
    get 'Get store branding and config' do
      tags 'Store'
      produces 'application/json'
      security [api_key: []]
      description 'Returns customer-facing store info: name, storefront URL, logo, and default/supported currencies and locales.'

      sdk_example 'store/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true

      response '200', 'store found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq(store.name)
          expect(data['default_currency']).to eq(store.default_currency)
          expect(data['default_locale']).to eq(store.default_locale)
          expect(data).to have_key('logo_url')
          expect(data).not_to have_key('mail_from_address')
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
