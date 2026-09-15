# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Transfers API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let(:seller_role) do
    create(:role, name: 'Seller', resource: seller, permissions: %w[read_seller_earnings])
  end

  let(:order) { create(:completed_order_with_totals, store: store, seller: seller) }
  let!(:transfer) { create(:seller_transfer, :completed, seller: seller, order: order, amount: 42) }

  path '/api/v3/seller/transfers' do
    get 'List transfers' do
      tags 'Earnings'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        What this seller has earned, order by order. A transfer is written
        when an order is fulfilled — the sale less the marketplace's
        commission — and a refund writes a negative `refund_reversal` row
        against it rather than editing it.

        Read-only. Filter with `q[order_id_eq]` for one order's rows, or
        `q[payout_id_eq]` for the earnings one settlement covers.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'
      parameter name: :'q[order_id_eq]', in: :query, type: :string, required: false, description: 'Only the rows for this order'
      parameter name: :'q[payout_id_eq]', in: :query, type: :string, required: false, description: 'Only the rows this settlement covers'
      parameter name: :'q[status_eq]', in: :query, required: false,
                schema: { type: :string, enum: %w[pending processing completed failed unresolved] }
      parameter name: :'q[kind_eq]', in: :query, required: false, schema: { type: :string, enum: Spree::SellerTransfer::KINDS }

      response '200', 'transfers listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Transfer' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |row| row['id'] }).to eq([transfer.prefixed_id])
        end
      end
    end
  end

  path '/api/v3/seller/transfers/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Transfer prefixed ID'

    get 'Get a transfer' do
      tags 'Earnings'
      produces 'application/json'
      security [bearer_auth: []]
      description "One of this seller's transfers. Another seller's is not found, whatever id is sent."

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'transfer found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { transfer.prefixed_id }

        schema '$ref' => '#/components/schemas/Transfer'

        run_test! do |response|
          expect(JSON.parse(response.body)['order_number']).to eq(order.number)
        end
      end

      response '404', 'transfer not found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { 'vtr_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
