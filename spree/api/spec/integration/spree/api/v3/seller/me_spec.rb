# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Account API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  path '/api/v3/seller/me' do
    get 'Current user' do
      tags 'Account'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The signed-in user, the sellers they may act for, and what they may do on
        the selected one.

        This is the one authenticated endpoint that answers without
        `X-Spree-Seller-Id` — it is what tells the panel which seller to name.
        Sending the header narrows `permission_keys` and `permissions` to that
        seller; without it both are empty, because capability is per seller and
        there is no answer spanning all of them.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: false,
                description: 'The seller to report capability for. Omit to list sellers without narrowing permissions.'

      response '200', 'current user returned' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema '$ref' => '#/components/schemas/SellerMeResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['user']['id']).to eq(seller_user.prefixed_id)
          expect(data['sellers'].first['id']).to eq(seller.prefixed_id)
          expect(data['permission_keys']).to include('write_products')
        end
      end

      response '401', 'missing or invalid token' do
        let(:Authorization) { nil }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
