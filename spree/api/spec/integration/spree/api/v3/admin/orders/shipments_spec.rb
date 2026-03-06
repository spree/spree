# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Shipments API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:order_ready_to_ship, store: store) }
  let!(:shipment) { order.shipments.first }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/orders/{order_id}/shipments' do
    let(:order_id) { order.prefixed_id }

    get 'List shipments' do
      tags 'Shipments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all shipments for an order.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'

      response '200', 'shipments found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].length).to eq(1)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/shipments/{id}' do
    let(:order_id) { order.prefixed_id }
    let(:id) { shipment.prefixed_id }

    get 'Show a shipment' do
      tags 'Shipments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns details of a specific shipment.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Shipment prefixed ID'

      response '200', 'shipment found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(shipment.prefixed_id)
          expect(data['number']).to be_present
        end
      end
    end

    patch 'Update a shipment' do
      tags 'Shipments'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a shipment (tracking, shipping rate).'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Shipment prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          tracking: { type: :string, example: '1Z999AA10123456784' },
          selected_shipping_rate_id: { type: :string }
        }
      }

      response '200', 'shipment updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { tracking: '1Z999AA10123456784' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['tracking']).to eq('1Z999AA10123456784')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/shipments/{id}/ship' do
    patch 'Ship a shipment' do
      tags 'Shipments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Marks a shipment as shipped.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Shipment prefixed ID'

      response '200', 'shipment shipped' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:id) { shipment.prefixed_id }

        before do
          shipment.ready! if shipment.can_ready?
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['state']).to eq('shipped')
        end
      end
    end
  end
end
