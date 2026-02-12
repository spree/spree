# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Line Items API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:order, store: store, user: user) }
  let!(:product) { create(:product, stores: [store]) }
  let!(:variant) { product.master }
  let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 1) }

  path '/api/v3/store/orders/{order_id}/line_items' do
    post 'Add item to cart' do
      tags 'Line Items'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a variant to the order. Creates a new line item or increases quantity if variant already in cart.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID or number'
      parameter name: :order_token, in: :query, type: :string, required: false,
                description: 'Order token for guest access'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          variant_id: { type: :string, description: 'Variant ID to add' },
          quantity: { type: :integer, description: 'Quantity to add (default: 1)' }
        },
        required: %w[variant_id]
      }

      response '201', 'line item created' do
        let(:new_product) { create(:product, stores: [store]) }
        let(:new_variant) { new_product.master }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:body) { { variant_id: new_variant.prefixed_id, quantity: 2 } }

        schema '$ref' => '#/components/schemas/StoreLineItem'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['quantity']).to eq(2)
        end
      end

      response '404', 'variant not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:body) { { variant_id: 'invalid', quantity: 1 } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'order not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { 'non-existent' }
        let(:body) { { variant_id: variant.prefixed_id, quantity: 1 } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/line_items/{id}' do
    patch 'Update line item quantity' do
      tags 'Line Items'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates the quantity of a line item in the cart'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :order_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true, description: 'Line item ID'
      parameter name: :order_token, in: :query, type: :string, required: false
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          quantity: { type: :integer, minimum: 1 }
        },
        required: %w[quantity]
      }

      response '200', 'line item updated' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:id) { line_item.to_param }
        let(:body) { { quantity: 5 } }

        schema '$ref' => '#/components/schemas/StoreLineItem'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['quantity']).to eq(5)
        end
      end

    end

    delete 'Remove line item from cart' do
      tags 'Line Items'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Removes a line item from the order'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :order_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :order_token, in: :query, type: :string, required: false

      response '204', 'line item removed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:id) { line_item.to_param }

        run_test! do
          expect(order.reload.line_items).to be_empty
        end
      end

      response '404', 'line item not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:id) { 'non-existent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
