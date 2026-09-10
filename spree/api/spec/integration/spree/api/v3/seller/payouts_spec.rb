# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Payouts API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let(:seller_role) do
    create(:role, name: 'Seller', resource: seller, permissions: %w[read_seller_earnings])
  end

  let!(:payout) { create(:seller_payout, seller: seller, amount: 120) }

  before do
    create(:seller_transfer, :completed, seller: seller, payout: payout, amount: 120,
                                         order: create(:completed_order_with_totals, store: store, seller: seller))
  end

  path '/api/v3/seller/payouts' do
    get 'List payouts' do
      tags 'Earnings'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Settlements to this seller: each one batches the transfers that had
        accumulated since the last, on the seller's payout schedule. `pending`
        and `processing` rows are owed; `completed` ones reached the seller's
        bank. `transfers_count` says how many earnings a settlement covers —
        list them with `GET /api/v3/seller/transfers?q[payout_id_eq]=…`.

        Read-only: a payout is created by the marketplace's sweep and
        confirmed by the payout provider or the operator.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'
      parameter name: :'q[status_eq]', in: :query, type: :string, required: false,
                enum: %w[pending processing completed failed unresolved]

      response '200', 'payouts listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Payout' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.first).to include('id' => payout.prefixed_id, 'transfers_count' => 1)
        end
      end
    end
  end

  path '/api/v3/seller/payouts/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Payout prefixed ID'

    get 'Get a payout' do
      tags 'Earnings'
      produces 'application/json'
      security [bearer_auth: []]
      description "One of this seller's settlements. Another seller's is not found, whatever id is sent."

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'payout found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { payout.prefixed_id }

        schema '$ref' => '#/components/schemas/Payout'

        run_test! do |response|
          expect(JSON.parse(response.body)['display_amount']).to eq('$120.00')
        end
      end

      response '404', 'payout not found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { 'vpo_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
