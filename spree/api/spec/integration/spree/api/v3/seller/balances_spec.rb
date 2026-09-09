# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Balances API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let(:seller_role) do
    create(:role, name: 'Seller', resource: seller, permissions: %w[read_seller_earnings])
  end

  before do
    create(:seller_transfer, :completed, seller: seller, amount: 40,
                                         order: create(:completed_order_with_totals, store: store, seller: seller))
    create(:seller_payout, :completed, seller: seller, amount: 15)
  end

  path '/api/v3/seller/balances' do
    get 'List balances' do
      tags 'Earnings'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Where this seller stands with the marketplace, one row per currency
        they have earned or been paid in: what they have earned (settled
        transfers, refund reversals included), what has reached them, what the
        marketplace still owes, and earnings the payout provider has not yet
        confirmed.

        Computed from the ledger rather than stored, so the rows carry no id
        and there is nothing to page.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'balances listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Balance' } }
               },
               required: %w[data]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.first).to include('currency' => 'USD', 'balance' => '25.0')
        end
      end
    end
  end
end
