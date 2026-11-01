# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Invoices API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # Invoices are a subject of the `orders` permission.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  let(:Authorization) { "Bearer #{seller_jwt_token}" }
  let(:'X-Spree-Seller-Id') { seller.prefixed_id }
  let!(:order) { create(:shipped_order, store: store, seller: seller, line_items_count: 1) }
  let!(:invoice) { create(:invoice, order: order) }
  let!(:commission_invoice) { create(:invoice, :commission, seller_payout: create(:seller_payout, seller: seller, store: store)) }
  let!(:other_sellers_invoice) do
    create(:invoice, order: create(:shipped_order, store: store, seller: create(:seller, store: store), line_items_count: 1))
  end

  path '/api/v3/seller/invoices' do
    get 'List invoices' do
      tags 'Invoices'
      produces 'application/json'
      security [bearer_auth: []]
      description "Invoices on this seller's orders, issued in the seller's name, and the commission invoices the marketplace issued them."
      seller_sdk_example 'invoices/list'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      filter_parameters_for

      response '200', 'invoices listed' do
        schema type: :object,
               properties: { data: { type: :array, items: { '$ref' => '#/components/schemas/Invoice' } } },
               required: %w[data]

        run_test! do |response|
          ids = JSON.parse(response.body)['data'].map { |row| row['id'] }
          expect(ids).to contain_exactly(invoice.prefixed_id, commission_invoice.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/seller/invoices/{id}' do
    parameter name: :id, in: :path, type: :string, required: true

    delete 'Delete an invoice' do
      tags 'Invoices'
      security [bearer_auth: []]
      description "Only an unsent upload on one of the seller's own orders. Commission invoices are the marketplace's."
      seller_sdk_example 'invoices/delete'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '204', 'invoice deleted' do
        let(:id) { invoice.prefixed_id }

        run_test!
      end

      response '404', 'a commission invoice' do
        let(:id) { commission_invoice.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/seller/invoices/{id}/download' do
    parameter name: :id, in: :path, type: :string, required: true

    get 'Download an invoice' do
      tags 'Invoices'
      security [bearer_auth: []]

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'the PDF' do
        let(:id) { commission_invoice.prefixed_id }

        run_test! { |response| expect(response.body).to start_with('%PDF') }
      end

      response '404', "another seller's invoice" do
        let(:id) { other_sellers_invoice.prefixed_id }

        run_test!
      end
    end
  end
end
