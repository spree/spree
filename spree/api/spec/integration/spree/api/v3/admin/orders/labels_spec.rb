# frozen_string_literal: true

require 'swagger_helper'
require 'spree/testing_support/label_provider'

RSpec.describe 'Admin Shipping Labels API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:order_ready_to_ship, store: store) }
  let!(:shipment) { order.fulfillments.first }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:signed_file) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4\n%label\n"), filename: 'label.pdf', content_type: 'application/pdf',
      service_name: Spree.private_storage_service_name
    ).signed_id
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{fulfillment_id}/labels' do
    let(:order_id) { order.prefixed_id }
    let(:fulfillment_id) { shipment.prefixed_id }

    get 'List shipping labels' do
      tags 'Shipping Labels'
      produces 'application/json'
      security [{ api_key: [], bearer_auth: [] }]
      description 'Every label bought or uploaded for a parcel, refunded ones included.'
      admin_scope :read, :fulfillments

      admin_sdk_example 'order-labels/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order ID'
      parameter name: :fulfillment_id, in: :path, type: :string, required: true, description: 'Fulfillment ID'

      response '200', 'labels found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        before { create(:shipping_label, owner: shipment, store: store) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].first['source']).to eq('purchased')
        end
      end
    end

    post 'Buy or record a shipping label' do
      tags 'Shipping Labels'
      consumes 'application/json'
      produces 'application/json'
      security [{ api_key: [], bearer_auth: [] }]
      description 'With no body, buys the label through the parcel\'s carrier account. With a `file`, records a label bought elsewhere. Either way the tracking number becomes a delivery on the parcel.'
      admin_scope :write, :fulfillments

      admin_sdk_example 'order-labels/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order ID'
      parameter name: :fulfillment_id, in: :path, type: :string, required: true, description: 'Fulfillment ID'
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          file: { type: :string, description: 'Signed blob id of an uploaded label file; its presence records rather than buys' },
          tracking_number: { type: :string, description: 'Number printed on an uploaded label' },
          carrier: { type: :string, description: 'Free-text carrier; detected from the number when omitted' },
          service: { type: :string, description: 'Carrier service the label was bought at' },
          cost: { type: :string, description: 'What the merchant paid the carrier' },
          currency: { type: :string, description: 'Currency of the cost' },
          file_format: { type: :string, enum: %w[pdf png zpl], description: 'Label file format; taken from the file when omitted' },
          tracking_url: { type: :string, description: 'Tracking page for the consignment' }
        }
      }

      response '201', 'label purchased' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { {} }

        before do
          shipment.deliveries.destroy_all
          allow(SsrfFilter).to receive(:get).and_raise(SocketError.new('offline'))
          allow_any_instance_of(Spree::Fulfillment).to receive(:provider).
            and_return(Spree::TestingSupport::LabelProvider.new)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['source']).to eq('purchased')
          expect(data['status']).to eq('purchased')
          expect(data['tracking_number']).to be_present
        end
      end

      response '422', 'provider does not produce labels' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { {} }

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{fulfillment_id}/labels/{id}' do
    let(:order_id) { order.prefixed_id }
    let(:fulfillment_id) { shipment.prefixed_id }
    let!(:shipping_label) { create(:shipping_label, :uploaded, owner: shipment, store: store) }
    let(:id) { shipping_label.prefixed_id }

    get 'Get a shipping label' do
      tags 'Shipping Labels'
      produces 'application/json'
      security [{ api_key: [], bearer_auth: [] }]
      description 'One label, with what it cost and where to print it from.'
      admin_scope :read, :fulfillments

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order ID'
      parameter name: :fulfillment_id, in: :path, type: :string, required: true, description: 'Fulfillment ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Shipping label ID'

      response '200', 'label found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(shipping_label.prefixed_id)
          expect(data['source']).to eq('uploaded')
        end
      end
    end

    delete 'Delete an uploaded label' do
      tags 'Shipping Labels'
      produces 'application/json'
      security [{ api_key: [], bearer_auth: [] }]
      description 'Removes an uploaded label. A purchased label is refunded instead, so the postage history stays honest.'
      admin_scope :write, :fulfillments

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order ID'
      parameter name: :fulfillment_id, in: :path, type: :string, required: true, description: 'Fulfillment ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Shipping label ID'

      response '204', 'label deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{fulfillment_id}/labels/{id}/refund' do
    patch 'Refund a shipping label' do
      tags 'Shipping Labels'
      produces 'application/json'
      security [{ api_key: [], bearer_auth: [] }]
      description 'Asks the carrier to refund a purchased label. The consignment it minted is removed when the parcel never shipped.'
      admin_scope :write, :fulfillments

      admin_sdk_example 'order-labels/refund'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order ID'
      parameter name: :fulfillment_id, in: :path, type: :string, required: true, description: 'Fulfillment ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Shipping label ID'

      response '200', 'refund filed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:fulfillment_id) { shipment.prefixed_id }
        let(:shipping_label) { create(:shipping_label, :with_delivery, owner: shipment, store: store) }
        let(:id) { shipping_label.prefixed_id }

        before do
          allow_any_instance_of(Spree::Fulfillment).to receive(:provider).
            and_return(Spree::TestingSupport::LabelProvider.new)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('refunded')
        end
      end

      response '422', 'uploaded labels cannot be refunded' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:fulfillment_id) { shipment.prefixed_id }
        let(:shipping_label) { create(:shipping_label, :uploaded, owner: shipment, store: store) }
        let(:id) { shipping_label.prefixed_id }

        run_test!
      end
    end
  end
end
