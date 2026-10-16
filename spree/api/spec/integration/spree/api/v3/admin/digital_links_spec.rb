# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Digital Links API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }
  let(:line_item) { order.line_items.first }
  let(:digital_asset) { create(:digital_asset, variant: line_item.variant) }
  let!(:digital_link) { create(:digital_link, digital_asset: digital_asset, line_item: line_item) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/digital_links' do
    get 'List digital links' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the download links issued for digital products bought in this store, newest first.'
      admin_scope :read, :orders

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      filter_parameters_for

      response '200', 'digital links found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('DigitalLink')

        run_test! do |response|
          ids = JSON.parse(response.body)['data'].map { |record| record['id'] }
          expect(ids).to eq([digital_link.prefixed_id])
        end
      end
    end
  end
end
