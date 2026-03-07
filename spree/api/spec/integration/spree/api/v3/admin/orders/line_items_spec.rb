# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Line Items API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:product) { create(:product, stores: [store]) }
  let!(:variant) { create(:variant, product: product) }
  let!(:order) { create(:order, store: store, state: 'cart') }
  let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 2) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/orders/{order_id}/line_items' do
    let(:order_id) { order.prefixed_id }

    get 'List line items' do
      tags 'Line Items'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all line items for an order.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'

      response '200', 'line items found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].length).to eq(1)
        end
      end
    end

    post 'Add a line item' do
      tags 'Line Items'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a new line item to the order.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[variant_id],
        properties: {
          variant_id: { type: :string, description: 'Prefixed variant ID' },
          quantity: { type: :integer, default: 1 }
        }
      }

      response '201', 'line item added' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:new_variant) { create(:variant, product: create(:product, stores: [store])) }
        let(:body) { { variant_id: new_variant.prefixed_id, quantity: 3 } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['quantity']).to eq(3)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/line_items/{id}' do
    let(:order_id) { order.prefixed_id }
    let(:id) { line_item.prefixed_id }

    get 'Show a line item' do
      tags 'Line Items'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns details of a specific line item.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Line item prefixed ID'

      response '200', 'line item found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(line_item.prefixed_id)
        end
      end
    end

    patch 'Update a line item' do
      tags 'Line Items'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a line item quantity or metadata.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Line item prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          quantity: { type: :integer }
        }
      }

      response '200', 'line item updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { quantity: 5 } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['quantity']).to eq(5)
        end
      end
    end

    delete 'Remove a line item' do
      tags 'Line Items'
      security [api_key: [], bearer_auth: []]
      description 'Removes a line item from the order.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Line item prefixed ID'

      response '204', 'line item removed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end
end
