# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Markets API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let!(:market) { create(:market, store: store, name: 'Europe') }

  path '/api/v3/seller/markets' do
    get 'List markets' do
      tags 'Markets'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The marketplace's markets, for choosing where a product may be sold.

        Read only: which markets exist is the marketplace's decision. Send the
        chosen ids as `market_ids` on the product, with `market_availability`
        set to `all_except` or `only`.
      DESC

      seller_sdk_example 'markets/list'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'

      response '200', 'markets listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Market' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.pluck('id')).to include(market.prefixed_id)
        end
      end
    end
  end
end
