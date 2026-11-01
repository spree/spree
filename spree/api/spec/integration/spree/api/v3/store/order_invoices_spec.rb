# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Order Invoices API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:order) { create(:completed_order_with_totals, store: store, customer: user) }
  let(:order_id) { order.prefixed_id }
  let!(:invoice) { create(:invoice, order: order) }

  path '/api/v3/store/orders/{order_id}/invoices' do
    parameter name: :order_id, in: :path, type: :string, required: true

    get "List the order's invoices" do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "The invoices, receipts and credit notes on one of the customer's orders. Accessible via JWT or the order token header for guests."
      sdk_example 'order-invoices/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      filter_parameters_for

      response '200', 'invoices listed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema SwaggerSchemaHelpers.paginated('Invoice')

        run_test! do |response|
          row = JSON.parse(response.body)['data'].first
          expect(row).to include('id' => invoice.prefixed_id, 'issuer_type' => 'store')
          expect(row).not_to have_key('source')
          expect(row['download_url']).to eq("/api/v3/store/orders/#{order.prefixed_id}/invoices/#{invoice.prefixed_id}/download")
        end
      end

      response '404', "somebody else's order" do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { create(:completed_order_with_totals, store: store).prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/invoices/{id}/download' do
    parameter name: :order_id, in: :path, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true

    get 'Download an invoice' do
      tags 'Orders'
      security [api_key: [], bearer_auth: []]
      description 'Streams the PDF to whoever owns the order.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false

      response '200', 'the PDF' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { invoice.prefixed_id }

        run_test! { |response| expect(response.body).to start_with('%PDF') }
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/invoice_requests' do
    parameter name: :order_id, in: :path, type: :string, required: true

    post 'Request an invoice' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Asks for an invoice on an order bought as a private buyer, within the store's request window and while the
        order has no invoice. Whoever issues the order's invoices is told through the `order.invoice_requested`
        event. Accessible via JWT or the order token header for guests.
      DESC
      sdk_example 'order-invoice-requests/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      request_body_for

      response '201', 'request recorded' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:requesting_order) { create(:completed_order_with_totals, store: store, customer: user).tap { |o| o.update_columns(status: 'placed') } }
        let(:order_id) { requesting_order.prefixed_id }
        let(:body) { { company_name: 'Acme GmbH', tax_id: 'DE123456789' } }

        schema '$ref' => '#/components/schemas/InvoiceRequest'

        run_test! do |response|
          expect(JSON.parse(response.body)).to include('status' => 'open', 'company_name' => 'Acme GmbH')
        end
      end

      response '422', 'the order already has an invoice' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { company_name: 'Acme GmbH' } }

        before { order.update_columns(status: 'placed') }

        run_test!
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/documents' do
    parameter name: :order_id, in: :path, type: :string, required: true

    get "List the order's documents" do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Documents the merchant made visible on the order, and those the customer added.'
      sdk_example 'order-documents/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      filter_parameters_for

      response '200', 'visible documents only' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let!(:visible) { create(:order_document, order: order, customer_visible: true) }
        let!(:internal) { create(:order_document, order: order) }

        schema SwaggerSchemaHelpers.paginated('OrderDocument')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].map { |row| row['id'] }).to eq([visible.prefixed_id])
        end
      end
    end

    post 'Add a document to the order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "The customer's own paperwork — a purchase order, a tax form. Always visible to them, flagged as theirs for the merchant."
      sdk_example 'order-documents/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      request_body_for

      response '201', 'document added' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:blob) do
          ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4\n%%EOF\n"), filename: 'po.pdf',
                                                 content_type: 'application/pdf', service_name: Spree.private_storage_service_name)
        end
        let(:body) { { label: 'Purchase order 4471', file_signed_id: blob.signed_id } }

        schema '$ref' => '#/components/schemas/OrderDocument'

        run_test! do |response|
          expect(JSON.parse(response.body)).to include('label' => 'Purchase order 4471', 'uploaded_by_customer' => true)
        end
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/documents/upload' do
    parameter name: :order_id, in: :path, type: :string, required: true

    post 'Prepare a document upload' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Prepares a private upload for a document the customer adds to their order. Send the file's metadata,
        `PUT` the bytes to `upload.url` with exactly `upload.headers`, then create the document with the
        returned `signed_id`. Returns 422 when the declared size or type is not accepted.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      request_body_for

      response '201', 'upload target created' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { filename: 'po.pdf', content_type: 'application/pdf', byte_size: 48_210, checksum: Digest::MD5.base64digest('po') } }

        schema SwaggerSchemaHelpers.ref('FileUpload')

        run_test! { |response| expect(JSON.parse(response.body)['visibility']).to eq('private') }
      end

      response '422', 'a file type documents do not accept' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { filename: 'run.sh', content_type: 'application/x-sh', byte_size: 100, checksum: Digest::MD5.base64digest('x') } }

        run_test!
      end
    end
  end
end
