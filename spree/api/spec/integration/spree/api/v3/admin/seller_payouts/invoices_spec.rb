# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Seller Payout Invoices API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:payout) { create(:seller_payout, store: store) }
  let(:seller_payout_id) { payout.prefixed_id }

  path '/api/v3/admin/seller_payouts/{seller_payout_id}/invoices' do
    parameter name: :seller_payout_id, in: :path, type: :string, required: true

    get "List a payout's commission invoices" do
      tags 'Invoices'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :payouts
      admin_sdk_example 'seller-payout-invoices/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      filter_parameters_for

      response '200', 'invoices found' do
        let!(:invoice) { create(:invoice, :commission, seller_payout: payout) }

        schema SwaggerSchemaHelpers.paginated('Invoice')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].first).to include('id' => invoice.prefixed_id, 'seller_payout_id' => payout.prefixed_id)
        end
      end
    end

    post 'Upload a commission invoice' do
      tags 'Invoices'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "The marketplace's invoice to the seller for the commission on this payout, " \
                  "issued in the operator's accounting system. The store is the issuer."
      admin_scope :write, :payouts
      admin_sdk_example 'seller-payout-invoices/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '201', 'commission invoice uploaded' do
        let(:blob) do
          ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4\n%%EOF\n"), filename: 'com.pdf',
                                                 content_type: 'application/pdf', service_name: Spree.private_storage_service_name)
        end
        let(:body) { { kind: 'invoice', number: 'COM/2026/11/3', issued_on: '2026-11-01', total: '12.30', file_signed_id: blob.signed_id } }

        schema '$ref' => '#/components/schemas/Invoice'

        run_test! do |response|
          expect(JSON.parse(response.body)).to include('issuer_type' => 'store', 'seller_payout_id' => payout.prefixed_id, 'order_id' => nil)
        end
      end
    end
  end
end
