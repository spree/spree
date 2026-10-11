# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Groups API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:order_group) { create(:order_group, store: store) }

  path '/api/v3/admin/order_groups' do
    get 'List order groups' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns checkouts split into one order per seller, grouping the orders placed together.'
      admin_scope :read, :orders

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      filter_parameters_for

      response '200', 'order groups found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('OrderGroup')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(order_group.prefixed_id)
        end
      end
    end
  end
end
