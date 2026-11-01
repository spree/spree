# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Invoices API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:order_id) { order.prefixed_id }
  let(:pdf) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4\n%%EOF\n"), filename: 'FV-2026-11-42.pdf', content_type: 'application/pdf',
      service_name: Spree.private_storage_service_name
    )
  end

  path '/api/v3/admin/orders/{order_id}/invoices' do
    parameter name: :order_id, in: :path, type: :string, required: true

    get "List an order's invoices" do
      tags 'Invoices'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :orders
      admin_sdk_example 'order-invoices/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      filter_parameters_for

      response '200', 'invoices found' do
        let!(:invoice) { create(:invoice, order: order) }

        schema SwaggerSchemaHelpers.paginated('Invoice')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].map { |row| row['id'] }).to eq([invoice.prefixed_id])
        end
      end
    end

    post 'Upload an invoice' do
      tags 'Invoices'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Records an invoice, receipt or credit note issued in another system — an ERP, an accounting tool, a
        national e-invoicing platform. Upload the PDF with `files.upload()` (`visibility: 'private'`) first and
        send its `signed_id`. The issuer is the order's seller of record: the seller for a seller's order,
        otherwise the store. An invoice of kind `invoice` fulfils the buyer's open invoice request. Invoices are
        never edited; correct one with a credit note.
      DESC
      admin_scope :write, :orders
      admin_sdk_example 'order-invoices/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '201', 'invoice uploaded' do
        let(:body) do
          { kind: 'invoice', number: 'FV/2026/11/42', issued_on: '2026-11-01', total: order.total.to_s, file_signed_id: pdf.signed_id }
        end

        schema '$ref' => '#/components/schemas/Invoice'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to include('number' => 'FV/2026/11/42', 'source' => 'uploaded', 'order_id' => order.prefixed_id)
          expect(order.invoices.count).to eq(1)
        end
      end

      response '422', 'number already used by this issuer' do
        before { create(:invoice, order: order, number: 'FV/2026/11/42') }

        let(:body) do
          { kind: 'invoice', number: 'FV/2026/11/42', issued_on: '2026-11-01', total: '10.00', file_signed_id: pdf.signed_id }
        end

        run_test!
      end

      response '404', "credit note pointing at another order's invoice" do
        let(:body) do
          { kind: 'credit_note', number: 'CN/1', issued_on: '2026-11-01', total: '-5.00', file_signed_id: pdf.signed_id,
            original_invoice_id: create(:invoice).prefixed_id }
        end

        run_test!
      end
    end
  end
end
