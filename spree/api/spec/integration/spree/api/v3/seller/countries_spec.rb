# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Countries API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  path '/api/v3/seller/countries' do
    get 'List countries' do
      tags 'Countries'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Countries and their states, for the panel's address forms.

        Public reference data — the same list the storefront serves — so it is
        not narrowed to the markets this marketplace sells into: a seller filling
        in a billing address needs every country.

        Unpaginated. An address dropdown needs all ~250 at once.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'countries listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/SellerCountry' } },
                 meta: {
                   type: :object,
                   properties: { count: { type: :integer, example: 250 } },
                   required: %w[count]
                 }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['meta']['count']).to eq(data['data'].size)
        end
      end
    end
  end
end
