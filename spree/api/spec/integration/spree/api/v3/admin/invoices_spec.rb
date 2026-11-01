# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Invoices API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let!(:invoice) { create(:invoice, order: order, number: 'FV/2026/11/1') }

  path '/api/v3/admin/invoices' do
    get 'List invoices' do
      tags 'Invoices'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Every invoice, receipt and credit note in the store, uploaded or generated, across orders and
        seller payouts — the list an accountant exports. Create one under the order or seller payout it
        belongs to.
      DESC
      admin_scope :read, :orders
      admin_sdk_example 'invoices/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand: `order`, `uploaded_by`.'
      filter_parameters_for

      response '200', 'invoices found' do
        schema SwaggerSchemaHelpers.paginated('Invoice')

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |row| row['id'] }).to eq([invoice.prefixed_id])
          expect(data.first).to include('kind' => 'invoice', 'number' => 'FV/2026/11/1', 'issuer_type' => 'store', 'source' => 'uploaded')
        end
      end
    end
  end

  path '/api/v3/admin/invoices/{id}' do
    parameter name: :id, in: :path, type: :string, required: true

    get 'Get an invoice' do
      tags 'Invoices'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :orders
      admin_sdk_example 'invoices/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'invoice found' do
        let(:id) { invoice.prefixed_id }

        schema '$ref' => '#/components/schemas/Invoice'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['download_url']).to eq("/api/v3/admin/invoices/#{invoice.prefixed_id}/download")
          expect(data['can_be_deleted']).to be(true)
        end
      end

      response '404', "another store's invoice" do
        let(:id) { create(:invoice, order: create(:completed_order_with_totals, store: create(:store))).prefixed_id }

        run_test!
      end
    end

    delete 'Delete an invoice' do
      tags 'Invoices'
      security [api_key: [], bearer_auth: []]
      description 'Only an upload the buyer has not been sent. A sent or generated invoice is corrected with a credit note.'
      admin_scope :write, :orders
      admin_sdk_example 'invoices/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'invoice deleted' do
        let(:id) { invoice.prefixed_id }

        run_test! { expect(Spree::Invoice.exists?(invoice.id)).to be(false) }
      end

      response '422', 'invoice already sent' do
        let(:id) { create(:invoice, :sent, order: order).prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/invoices/{id}/download' do
    parameter name: :id, in: :path, type: :string, required: true

    get 'Download an invoice' do
      tags 'Invoices'
      produces 'application/pdf'
      security [api_key: [], bearer_auth: []]
      description 'Streams the PDF. Served through the API, never a storage link, so these credentials protect it.'
      admin_scope :read, :orders

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'the PDF' do
        let(:id) { invoice.prefixed_id }

        run_test! do |response|
          expect(response.body).to start_with('%PDF')
          expect(response.headers['Content-Disposition']).to include('attachment')
        end
      end
    end
  end

  path '/api/v3/admin/invoices/{id}/resend' do
    parameter name: :id, in: :path, type: :string, required: true

    post 'Send an invoice again' do
      tags 'Invoices'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "Emails the invoice to the order's buyer, or a commission invoice to the seller, whatever the store's automatic invoice email setting says."
      admin_scope :write, :orders
      admin_sdk_example 'invoices/resend'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '202', 'sending' do
        let(:id) { invoice.prefixed_id }

        schema '$ref' => '#/components/schemas/Invoice'

        run_test!
      end
    end
  end
end
