# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Roles API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:admin_role) { Spree::Role.default_admin_role }

  path '/api/v3/admin/roles' do
    get 'List roles' do
      tags 'Staff'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns staff roles with their catalog permissions. Roles are global, not per-store; ' \
                  '`mutable: false` marks the protected admin role and host-locked rows.'
      admin_scope :read, :staff

      admin_sdk_example 'roles/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'roles found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].pluck('name')).to include('admin')
        end
      end
    end

    post 'Create a role' do
      tags 'Staff'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a staff role. `permissions` holds catalog keys (see GET /admin/permissions); ' \
                  'a caller may only grant keys they effectively hold.'
      admin_scope :write, :staff

      admin_sdk_example 'roles/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :role, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'order_manager' },
          description: { type: :string, nullable: true, example: 'Handles daily orders' },
          permissions: { type: :array, items: { type: :string }, example: %w[write_orders read_customers] }
        },
        required: %w[name]
      }

      response '201', 'role created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:role) { { name: 'order_manager', description: 'Handles daily orders', permissions: %w[write_orders read_customers] } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('order_manager')
          expect(data['permissions']).to eq(%w[write_orders read_customers])
        end
      end

      response '422', 'invalid request' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:role) { { name: 'broken', permissions: %w[write_bogus] } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/roles/{id}' do
    parameter name: :id, in: :path, type: :string

    patch 'Update a role' do
      tags 'Staff'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a role name, description or permissions. The admin role and host-locked ' \
                  'roles (`mutable: false`) reject changes.'
      admin_scope :write, :staff

      admin_sdk_example 'roles/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :role, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string, nullable: true },
          permissions: { type: :array, items: { type: :string } }
        }
      }

      response '200', 'role updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:existing_role) { create(:role, name: 'support', permissions: %w[read_orders]) }
        let(:id) { existing_role.prefixed_id }
        let(:role) { { permissions: %w[read_orders read_customers] } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['permissions']).to eq(%w[read_orders read_customers])
        end
      end
    end

    delete 'Delete a role' do
      tags 'Staff'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Deletes a role. Fails with 422 while the role is protected or still referenced by ' \
                  'staff members or pending invitations.'
      admin_scope :write, :staff

      admin_sdk_example 'roles/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'role deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { create(:role, name: 'obsolete').prefixed_id }

        run_test!
      end

      response '422', 'role cannot be deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { admin_role.prefixed_id }

        run_test!
      end
    end
  end
end
