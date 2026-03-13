# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Cart Items API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:order, store: store, user: user) }
  let!(:product) { create(:product, stores: [store]) }
  let!(:variant) { product.master }
  let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 1) }
  let(:cart_id) { order.prefixed_id }

  path '/api/v3/store/carts/{cart_id}/items' do
    post 'Add item to cart' do
      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a variant to the cart. Creates a new line item or increases quantity if variant already in cart.'

      sdk_example <<~JS
        const cart = await client.carts.items.create('cart_abc123', {
          variant_id: 'variant_abc123',
          quantity: 2,
        }, {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'
      parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID (e.g., cart_abc123)'
      parameter name: 'Idempotency-Key', in: :header, type: :string, required: false,
                description: 'Unique key for request idempotency.'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          variant_id: { type: :string, example: 'variant_abc123', description: 'Variant ID to add' },
          quantity: { type: :integer, example: 2, description: 'Quantity to add (default: 1)' },
          metadata: { type: :object, additionalProperties: true, description: 'Arbitrary key-value metadata', example: { gift_message: 'Happy Birthday!' } }
        },
        required: %w[variant_id]
      }

      response '201', 'item added, returns updated cart' do
        let(:new_product) { create(:product, stores: [store]) }
        let(:new_variant) { new_product.master }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { variant_id: new_variant.prefixed_id, quantity: 2 } }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['number']).to eq(order.number)
          expect(data['items'].first).to have_key('currency')
        end
      end

      response '201', 'item added with metadata' do
        let(:new_product) { create(:product, stores: [store]) }
        let(:new_variant) { new_product.master }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { variant_id: new_variant.prefixed_id, quantity: 1, metadata: { gift_message: 'Happy Birthday!' } } }

        run_test! do |_response|
          new_line_item = order.reload.line_items.find_by(variant: new_variant)
          expect(new_line_item.metadata).to include('gift_message' => 'Happy Birthday!')
        end
      end

      response '404', 'variant not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { variant_id: 'invalid', quantity: 1 } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/carts/{cart_id}/items/{id}' do
    patch 'Update line item quantity' do
      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates the quantity of a line item in the cart'

      sdk_example <<~JS
        const cart = await client.carts.items.update('cart_abc123', 'li_abc123', {
          quantity: 5,
        }, {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Line item ID'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          quantity: { type: :integer, minimum: 1, example: 5 },
          metadata: { type: :object, additionalProperties: true, description: 'Arbitrary key-value metadata (merged with existing)', example: { engraving: 'J.D.' } }
        }
      }

      response '200', 'quantity updated, returns updated cart' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { line_item.to_param }
        let(:body) { { quantity: 5 } }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['number']).to eq(order.number)
          expect(line_item.reload.quantity).to eq(5)
        end
      end

      response '200', 'metadata updated on line item' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { line_item.to_param }
        let(:body) { { metadata: { engraving: 'J.D.' } } }

        run_test! do |_response|
          expect(line_item.reload.metadata).to include('engraving' => 'J.D.')
        end
      end
    end

    delete 'Remove line item from cart' do
      tags 'Carts'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Removes a line item from the cart'

      sdk_example <<~JS
        const cart = await client.carts.items.delete('cart_abc123', 'li_abc123', {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: 'x-spree-token', in: :header, type: :string, required: false

      response '200', 'line item removed, returns updated cart' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { line_item.to_param }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          expect(order.reload.line_items).to be_empty
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['number']).to eq(order.number)
        end
      end

      response '404', 'line item not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'non-existent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
