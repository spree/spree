# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Documents API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:order_id) { order.prefixed_id }
  let!(:document) { create(:order_document, order: order) }

  path '/api/v3/admin/orders/{order_id}/documents' do
    parameter name: :order_id, in: :path, type: :string, required: true

    get "List an order's documents" do
      tags 'Order Documents'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Paperwork on the order that is not an invoice: the buyer\'s PO, specifications, shipping documents.'
      admin_scope :read, :orders
      admin_sdk_example 'order-documents/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      filter_parameters_for

      response '200', 'documents found' do
        schema SwaggerSchemaHelpers.paginated('OrderDocument')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].first).to include('label' => 'Signed purchase order', 'customer_visible' => false)
        end
      end
    end

    post 'Upload an order document' do
      tags 'Order Documents'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Private to staff unless `customer_visible` is set. Invoices go to `/orders/{order_id}/invoices`.'
      admin_scope :write, :orders
      admin_sdk_example 'order-documents/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '201', 'document uploaded' do
        let(:blob) do
          ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4\n%%EOF\n"), filename: 'spec.pdf',
                                                 content_type: 'application/pdf', service_name: Spree.private_storage_service_name)
        end
        let(:body) { { label: 'Technical specification', customer_visible: true, file_signed_id: blob.signed_id } }

        schema '$ref' => '#/components/schemas/OrderDocument'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to include('label' => 'Technical specification', 'customer_visible' => true, 'uploaded_by_type' => 'admin_user')
        end
      end

      response '422', 'no file' do
        let(:body) { { label: 'Nothing attached' } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/documents/{id}' do
    parameter name: :order_id, in: :path, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true

    patch 'Update an order document' do
      tags 'Order Documents'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Renames it or changes whether the buyer sees it. The file itself is replaced by uploading a new document.'
      admin_scope :write, :orders
      admin_sdk_example 'order-documents/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '200', 'document updated' do
        let(:id) { document.prefixed_id }
        let(:body) { { customer_visible: true } }

        schema '$ref' => '#/components/schemas/OrderDocument'

        run_test! { expect(document.reload.customer_visible).to be(true) }
      end
    end

    delete 'Delete an order document' do
      tags 'Order Documents'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :orders
      admin_sdk_example 'order-documents/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'document deleted' do
        let(:id) { document.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/documents/{id}/download' do
    parameter name: :order_id, in: :path, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true

    get 'Download an order document' do
      tags 'Order Documents'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :orders
      admin_sdk_example 'order-documents/download'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'the file' do
        let(:id) { document.prefixed_id }

        run_test! { |response| expect(response.body).to start_with('%PDF') }
      end
    end
  end
end
