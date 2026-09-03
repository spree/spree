# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Commission Lines API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:seller) { create(:seller, :approved, store: store, name: 'Sparks Audio') }
  let(:order) { create(:order, store: store) }
  let!(:commission_line) do
    create(:commission_line, order: order, seller: seller, line_item: create(:line_item, order: order),
                             amount: 10, tax_amount: 2.1, total: 12.1, currency: 'USD')
  end

  path '/api/v3/admin/commission_lines' do
    get 'List commission lines' do
      tags 'Commission Lines'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        What each sale actually earned the marketplace, frozen when the order
        was placed. A later change to a commission rate never reaches these.

        `amount` is the fee charged to the seller and `tax_amount` is the VAT on
        that fee — the marketplace's own service to the seller, a supply
        separate from the sale itself, which is why the two are not folded
        together. `total` is their sum.

        One line per commissioned item, plus one per delivery when the rate that
        applied charges shipping too — read `line_item_id` and `fulfillment_id`
        to tell them apart.

        Read-only: correcting a charge is a reversal, not an edit.
      DESC
      admin_scope :read, :commissions

      admin_sdk_example 'commission_lines/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'Number of records per page'
      parameter name: :'q[seller_id_eq]', in: :query, type: :string, required: false,
                description: 'Filter to one seller'
      parameter name: :'q[order_id_eq]', in: :query, type: :string, required: false,
                description: 'Filter to one order'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to embed (e.g., `commission_rate`).'

      response '200', 'commission lines found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('CommissionLine')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(commission_line.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/commission_lines/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Commission line ID'

    get 'Get a commission line' do
      tags 'Commission Lines'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :commissions

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'commission line found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { commission_line.prefixed_id }

        schema '$ref' => '#/components/schemas/CommissionLine'

        run_test! do |response|
          expect(JSON.parse(response.body)['total']).to eq('12.1')
        end
      end

      response '404', 'commission line not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'cline_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
