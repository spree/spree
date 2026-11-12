# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Cart Tax Identifier API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:cart) { create(:cart_with_line_items, store: store, customer: user) }

  path '/api/v3/store/carts/{cart_id}/tax_identifier' do
    parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'

    patch 'Set the cart tax identifier' do
      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Sets the tax registration this cart is taxed against, overriding the one on the
        customer's profile — for a buyer paying through a different company than the one
        on their account. Send both `kind` and `value` every time. The cart's totals are
        recalculated. Returns 201 when the cart had no override yet, 200 when it replaced one.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      request_body_for

      response '201', 'tax identifier set' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:cart_id) { cart.prefixed_id }
        let(:body) { { kind: 'eu_vat', value: TaxIdentifierValidatorHelpers.eu_vat_number(0) } }

        schema '$ref' => '#/components/schemas/TaxIdentifier'

        run_test! do |response|
          expect(JSON.parse(response.body)['kind']).to eq('eu_vat')
          expect(cart.reload.tax_identifier).to be_present
        end
      end
    end
  end
end
