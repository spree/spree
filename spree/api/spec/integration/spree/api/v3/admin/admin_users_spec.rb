# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Staff API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:admin_role) { Spree::Role.default_admin_role }

  # The shared `admin_user` factory creates a RoleUser via its `after_create`
  # callback, but the resource defaults to `Spree::Current.store`, which may
  # not be set during request specs. We explicitly create the staff member
  # and pin the role assignment to `store` so the staff list returns it.
  let!(:staff_member) do
    user = admin_user
    user.role_users.find_or_create_by!(role: admin_role, resource: store)
    user
  end

  # A second store admin so removing `staff_member`'s role assignment below
  # doesn't trip the last-admin lockout guard (F14) — the store must always
  # keep at least one admin.
  let!(:second_admin) do
    create(:admin_user, :without_admin_role).tap { |u| u.role_users.create!(role: admin_role, resource: store) }
  end

  path '/api/v3/admin/admin_users' do
    get 'List staff' do
      tags 'Staff'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns admin users with at least one role assignment on the current store.'
      admin_scope :read, :settings

      admin_sdk_example 'admin-users/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'staff found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].pluck('id')).to include(staff_member.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/admin/admin_users/{id}' do
    let(:id) { staff_member.prefixed_id }

    get 'Show a staff member' do
      tags 'Staff'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :settings

      admin_sdk_example 'admin-users/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'staff member found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(staff_member.prefixed_id)
          expect(data['roles']).to be_an(Array)
          expect(data['roles'].pluck('name')).to include('admin')
        end
      end
    end

    patch 'Update a staff member' do
      tags 'Staff'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates name fields and reassigns roles for the current store. ' \
                  '`role_ids` is a complete replacement — roles not in the array are removed for this store.'
      admin_scope :write, :settings

      admin_sdk_example 'admin-users/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          first_name: { type: :string, example: 'Ada' },
          last_name: { type: :string, example: 'Lovelace' },
          role_ids: { type: :array, items: { type: :string } }
        }
      }

      response '200', 'staff member updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { first_name: 'Renamed', role_ids: [admin_role.prefixed_id] } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['first_name']).to eq('Renamed')
          expect(data['roles'].pluck('name')).to include('admin')
        end
      end
    end

    delete 'Remove a staff member from this store' do
      tags 'Staff'
      security [api_key: [], bearer_auth: []]
      description "Removes the user's role assignments on the current store. The account is preserved — the user keeps access to any other stores."
      admin_scope :write, :settings

      admin_sdk_example 'admin-users/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'staff removed from store' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          # Account still exists; only the per-store RoleUser is gone.
          expect(Spree.admin_user_class.exists?(staff_member.id)).to be true
          expect(staff_member.role_users.where(resource: store).exists?).to be false
        end
      end
    end
  end
end
