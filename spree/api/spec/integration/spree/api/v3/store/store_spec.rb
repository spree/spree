# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Store API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  path '/api/v3/store/store' do
    get 'Get the current store' do
      tags 'Store'
      produces 'application/json'
      security [api_key: []]
      description "Returns the current store's name, default SEO metadata, logo, social accounts and customer support " \
                  'email, so a storefront can render its page metadata and structured data. ' \
                  "Translated fields use the requested locale; one without a translation falls back to the store's default locale."

      sdk_example 'store/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'x-spree-locale', in: :header, type: :string, required: false,
                description: 'Locale for translated values, e.g. `de`. Defaults to the store locale.'

      response '200', 'store found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'x-spree-locale') { nil }

        schema '$ref' => '#/components/schemas/Store'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(store.prefixed_id)
          expect(data['name']).to eq(store.name)
          expect(data['customer_support_email']).to eq(store.customer_support_email)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:'x-spree-locale') { nil }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
