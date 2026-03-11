# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Checkout Payment Methods API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:order_with_line_items, store: store, user: user, state: 'payment') }
  let!(:payment_method) { create(:credit_card_payment_method, stores: [store], display_on: 'both') }
  let!(:backend_only_pm) { create(:credit_card_payment_method, stores: [store], display_on: 'back_end') }

  path '/api/v3/store/checkout/payment_methods' do
    get 'List available payment methods' do
      tags 'Checkout'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns payment methods available for the current cart based on store configuration and order state.'

      sdk_example <<~JS
        const methods = await client.checkout.paymentMethods.list({
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'

      response '200', 'payment methods found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/PaymentMethod' } },
                 meta: {
                   type: :object,
                   properties: {
                     count: { type: :integer }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          # Only frontend-visible payment methods should be returned
          expect(data['data'].map { |pm| pm['id'] }).to include(payment_method.prefixed_id)
          expect(data['data'].map { |pm| pm['id'] }).not_to include(backend_only_pm.prefixed_id)
        end
      end
    end
  end
end
