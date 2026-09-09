# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Deliveries API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:order_ready_to_ship, store: store) }
  let!(:shipment) { order.fulfillments.first }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/orders/{order_id}/fulfillments/{fulfillment_id}/deliveries' do
    let(:order_id) { order.prefixed_id }
    let(:fulfillment_id) { shipment.prefixed_id }

    get 'List deliveries' do
      tags 'Deliveries'
      produces 'application/json'
      security [{ api_key: [], bearer_auth: [] }]
      description 'The consignments of a parcel — one per tracking number, each with the carrier status last reported.'
      admin_scope :read, :fulfillments

      admin_sdk_example 'order-deliveries/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order ID'
      parameter name: :fulfillment_id, in: :path, type: :string, required: true, description: 'Fulfillment ID'

      response '200', 'deliveries found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].first['status']).to eq('pending')
        end
      end
    end

    post 'Record a delivery' do
      tags 'Deliveries'
      consumes 'application/json'
      produces 'application/json'
      security [{ api_key: [], bearer_auth: [] }]
      description 'Adds a tracked consignment to a parcel — a second box, or a freight PRO number covering several pallets. The carrier is free text.'
      admin_scope :write, :fulfillments

      admin_sdk_example 'order-deliveries/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order ID'
      parameter name: :fulfillment_id, in: :path, type: :string, required: true, description: 'Fulfillment ID'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        required: %w[tracking_number],
        properties: {
          tracking_number: { type: :string, description: 'Carrier tracking number, freight PRO number, or a full tracking link' },
          carrier: { type: :string, description: 'Free-text carrier; detected from the number when omitted' },
          service: { type: :string, description: 'Carrier service' },
          tracking_url: { type: :string, description: 'Tracking page for this consignment' }
        }
      }

      response '201', 'delivery recorded' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { tracking_number: '1Z879E930346834440' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['carrier']).to eq('ups')
          expect(data['status']).to eq('pending')
        end
      end

      response '422', 'tracking number already recorded on this parcel' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { tracking_number: shipment.tracking } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{fulfillment_id}/deliveries/{id}' do
    let(:order_id) { order.prefixed_id }
    let(:fulfillment_id) { shipment.prefixed_id }
    let(:id) { shipment.deliveries.first.prefixed_id }

    patch 'Correct a delivery' do
      tags 'Deliveries'
      consumes 'application/json'
      produces 'application/json'
      security [{ api_key: [], bearer_auth: [] }]
      description 'Corrects the tracking number, carrier or link. A corrected number starts the carrier journey over.'
      admin_scope :write, :fulfillments

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order ID'
      parameter name: :fulfillment_id, in: :path, type: :string, required: true, description: 'Fulfillment ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Delivery ID'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          tracking_number: { type: :string },
          carrier: { type: :string },
          service: { type: :string },
          tracking_url: { type: :string }
        }
      }

      response '200', 'delivery updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { tracking_number: 'CORRECTED-1' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['tracking_number']).to eq('CORRECTED-1')
        end
      end
    end

    delete 'Delete a delivery' do
      tags 'Deliveries'
      produces 'application/json'
      security [{ api_key: [], bearer_auth: [] }]
      description 'Removes a hand-entered consignment. One a label minted is refused — refund the label instead.'
      admin_scope :write, :fulfillments

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order ID'
      parameter name: :fulfillment_id, in: :path, type: :string, required: true, description: 'Fulfillment ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Delivery ID'

      response '204', 'delivery deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{fulfillment_id}/deliveries/{id}/mark_delivered' do
    patch 'Mark a delivery delivered' do
      tags 'Deliveries'
      consumes 'application/json'
      produces 'application/json'
      security [{ api_key: [], bearer_auth: [] }]
      description 'Staff confirming one consignment arrived. The parcel becomes delivered once every one of its consignments has.'
      admin_scope :write, :fulfillments

      admin_sdk_example 'order-deliveries/mark-delivered'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order ID'
      parameter name: :fulfillment_id, in: :path, type: :string, required: true, description: 'Fulfillment ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Delivery ID'
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          delivered_at: { type: :string, format: 'date-time', description: 'When it arrived. Defaults to now.' },
          notify_customer: { type: :boolean, description: 'Whether the customer gets a delivery notification when the parcel completes.' }
        }
      }

      response '200', 'delivery marked delivered' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:fulfillment_id) { shipment.prefixed_id }
        let(:id) { shipment.deliveries.first.prefixed_id }
        let(:body) { {} }

        before { Spree.fulfillment_fulfill_workflow.call(fulfillment: shipment) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('delivered')
          expect(data['delivered_at']).to be_present
        end
      end
    end
  end
end
