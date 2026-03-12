# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Carts API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:user) { create(:user_with_addresses) }

  path '/api/v3/store/carts' do
    get 'List active carts' do
      tags 'Cart'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all active (incomplete) carts for the authenticated user. Useful for users who may have multiple carts.'

      sdk_example <<~JS
        const carts = await client.carts.list({
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true

      response '200', 'carts listed' do
        let!(:cart1) { create(:order_with_line_items, store: store, user: user) }
        let!(:cart2) { create(:order_with_line_items, store: store, user: user) }
        let!(:completed_order) { create(:completed_order_with_totals, store: store, user: user) }
        let!(:other_user_cart) { create(:order_with_line_items, store: store, user: create(:user)) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          ids = data['data'].map { |c| c['id'] }
          # All cart IDs should use cart_ prefix
          expect(ids).to all(start_with('cart_'))
          expect(ids.size).to eq(2)
          expect(data['meta']['count']).to eq(2)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
