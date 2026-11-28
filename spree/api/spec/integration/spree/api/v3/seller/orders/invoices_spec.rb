# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Order Invoices API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  let(:Authorization) { "Bearer #{seller_jwt_token}" }
  let(:'X-Spree-Seller-Id') { seller.prefixed_id }
  let!(:order) { create(:shipped_order, store: store, seller: seller, line_items_count: 1) }
  let(:order_id) { order.prefixed_id }

  path '/api/v3/seller/orders/{order_id}/invoices' do
    parameter name: :order_id, in: :path, type: :string, required: true

    post 'Upload an invoice' do
      tags 'Invoices'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Records an invoice, receipt or credit note the seller issued in their own invoicing software. The
        seller is the issuer. An invoice of kind `invoice` fulfils the buyer's open invoice request.
      DESC
      seller_sdk_example 'order-invoices/create'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

      response '201', 'invoice uploaded' do
        let!(:invoice_request) { create(:invoice_request, order: order) }
        let(:blob) do
          ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4\n%%EOF\n"), filename: 'fv.pdf',
                                                 content_type: 'application/pdf', service_name: Spree.private_storage_service_name)
        end
        let(:body) { { kind: 'invoice', number: 'S-17', issued_on: '2026-11-01', total: order.total.to_s, file_signed_id: blob.signed_id } }

        schema '$ref' => '#/components/schemas/Invoice'

        run_test! do |response|
          expect(JSON.parse(response.body)).to include('issuer_type' => 'seller', 'issuer_id' => seller.prefixed_id)
          expect(invoice_request.reload.status).to eq('fulfilled')
        end
      end

      response '422', 'an order the marketplace invoices' do
        before { seller.update!(tax_remittance: 'platform') }

        let(:blob) do
          ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4\n%%EOF\n"), filename: 'fv.pdf',
                                                 content_type: 'application/pdf', service_name: Spree.private_storage_service_name)
        end
        let(:body) { { kind: 'invoice', number: 'S-19', issued_on: '2026-11-01', total: '1.00', file_signed_id: blob.signed_id } }

        run_test!
      end

      response '404', "another seller's order" do
        let(:order_id) { create(:shipped_order, store: store, seller: create(:seller, store: store), line_items_count: 1).prefixed_id }
        let(:body) { { kind: 'invoice', number: 'S-18', issued_on: '2026-11-01', total: '1.00', file_signed_id: 'x' } }

        run_test!
      end
    end
  end
end
