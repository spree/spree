# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Payment Methods API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:user) { create(:user) }
  let!(:order) { create(:order_with_line_items, store: store, user: user, state: 'payment') }
  let!(:payment_method) { create(:credit_card_payment_method, stores: [store], display_on: 'both') }
  let!(:backend_only_pm) { create(:credit_card_payment_method, stores: [store], display_on: 'back_end') }

  path '/api/v3/store/orders/{order_id}/payment_methods' do
    get 'List available payment methods' do
      tags 'Payment Methods'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns payment methods available for the order based on store configuration and order state'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :order_id, in: :path, type: :string, required: true
      parameter name: :order_token, in: :query, type: :string, required: false

      response '200', 'payment methods found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.number }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/StorePaymentMethod' } },
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
          expect(data['data'].map { |pm| pm['id'] }).to include(payment_method.prefix_id)
          expect(data['data'].map { |pm| pm['id'] }).not_to include(backend_only_pm.prefix_id)
        end
      end

      response '404', 'order not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { 'non-existent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:order_id) { order.number }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
