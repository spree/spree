# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Permissions API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/permissions' do
    get 'List the permission catalog' do
      tags 'Staff'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the permission catalog — the grant vocabulary shared by staff role ' \
                  'permissions and secret API key scopes. Entries are grouped for permission pickers; ' \
                  'labels and descriptions are localized. Readable by any authenticated admin credential.'

      admin_sdk_example 'permissions/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'catalog returned' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('key')).to include('read_orders', 'write_orders', 'write_staff')
          entry = data['data'].find { |e| e['key'] == 'write_orders' }
          expect(entry).to include('resource' => 'orders', 'kind' => 'write', 'group' => 'orders')
        end
      end
    end
  end
end
