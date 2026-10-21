# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Cart Addresses API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:cart) { create(:cart_with_line_items, store: store, customer: user) }
  let!(:address) { create(:address, customer: user) }

  path '/api/v3/store/carts/{cart_id}/addresses' do
    parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'

    get 'List addresses this cart may use' do
      tags 'Carts'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Everything a checkout address step may offer for this cart: the buyer's own address
        book, plus the address book of the company the cart is for — that company's own
        sites and the ones it inherits from the companies above it.

        Requires a signed-in customer, unlike the rest of the cart endpoints. The response
        is the account's address books rather than the cart's own data, so a guest cart
        token is not accepted here. A guest cart has neither book and would get an empty
        list in any case.

        Each entry carries the `owner` it was filed under — the customer, or the company
        node that owns the site — so a picker can group and label them without asking
        which company the cart is for. An inherited site names the node above, not the
        one the cart is for.

        Any address returned here is accepted as `shipping_address_id` or
        `billing_address_id` on the cart, so the picker and the cart cannot disagree.
        Curating either book stays with `/store/customers/me/addresses` and
        `/store/companies/{company_id}/addresses`.
      DESC

      sdk_example 'cart-addresses/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false
      filter_parameters_for

      response '200', 'addresses found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:cart_id) { cart.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Address' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |row| row['id'] }).to include(address.prefixed_id)
          expect(data['data'].first['owner']['type']).to eq('customer')
        end
      end

      response '401', 'not authenticated' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { nil }
        let(:cart_id) { cart.prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'cart not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:cart_id) { 'cart_missing' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
