# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Stock Reservations API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }
  let!(:stock_reservation) { create(:stock_reservation, order: order) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/stock_reservations' do
    get 'List stock reservations' do
      tags 'Stock'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the stock held for orders that are being checked out, so it cannot be sold twice before they complete or the hold expires.'
      admin_scope :read, :stock

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      filter_parameters_for

      response '200', 'stock reservations found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('StockReservation')

        run_test! do |response|
          ids = JSON.parse(response.body)['data'].map { |record| record['id'] }
          expect(ids).to eq([stock_reservation.prefixed_id])
        end
      end
    end
  end
end
