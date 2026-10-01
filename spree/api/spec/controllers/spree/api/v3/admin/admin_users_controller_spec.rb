require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::AdminUsersController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  let!(:admin_role) { Spree::Role.default_admin_role }
  let(:staff_role) { create(:role, name: 'staff') }
  # A staff member already on this store (so the controller's store-scoped
  # `scope` resolves them) but without the admin role.
  let!(:target) do
    create(:admin_user, :without_admin_role).tap do |u|
      create(:role_user, user: u, role: staff_role)
    end
  end

  before { request.headers.merge!(headers) }

  describe 'PATCH #update — role-grant privilege escalation' do
    context 'authenticated via a secret API key (no human identity)' do
      let(:caller_key) { create(:api_key, :secret, store: store, scopes: ['write_staff']) }
      let(:headers) { { 'x-spree-api-key' => caller_key.plaintext_token } }

      it 'forbids granting the admin role' do
        patch :update, params: { id: target.prefixed_id, role_ids: [admin_role.prefixed_id] }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(target.reload.spree_admin?(store)).to be(false)
      end

      it 'still allows assigning a non-admin role' do
        other_role = create(:role, name: 'support')

        patch :update, params: { id: target.prefixed_id, role_ids: [other_role.prefixed_id] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(target.role_users.where(role: other_role)).to exist
      end
    end

    context 'authenticated as a staff JWT without staff permissions' do
      let(:orders_role) { create(:role, name: 'orders_only', permissions: %w[write_orders]) }
      let(:staff_admin) do
        create(:admin_user, :without_admin_role).tap { |u| create(:role_user, user: u, role: orders_role) }
      end
      let(:headers) do
        api_key_headers.merge('Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(staff_admin, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}")
      end

      # Staff records are invisible to a caller without staff permissions —
      # the ability-scoped lookup 404s before any role mutation is reachable.
      it 'cannot promote an account to admin' do
        patch :update, params: { id: target.prefixed_id, role_ids: [admin_role.prefixed_id] }, as: :json

        expect(response).to have_http_status(:not_found)
        expect(target.reload.spree_admin?(store)).to be(false)
      end

      it 'cannot assign any role' do
        expect {
          patch :update, params: { id: target.prefixed_id, role_ids: [staff_role.prefixed_id] }, as: :json
        }.not_to change { target.role_users.where(role: store.roles).count }

        expect(response).to have_http_status(:not_found)
      end

      # Unknown role ids must not slip the gates: the reconciliation would
      # otherwise strip the target's existing roles.
      it 'cannot mutate roles with unresolved role ids' do
        expect {
          patch :update, params: { id: target.prefixed_id, role_ids: ['role_nonexistent'] }, as: :json
        }.not_to change { target.role_users.where(role: store.roles).count }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'authenticated as a staff JWT holding write_staff' do
      let(:manager_role) { create(:role, name: 'team_manager', permissions: %w[write_staff]) }
      let(:staff_admin) do
        create(:admin_user, :without_admin_role).tap { |u| create(:role_user, user: u, role: manager_role) }
      end
      let(:headers) do
        api_key_headers.merge('Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(staff_admin, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}")
      end

      it 'allows assigning a non-privileged role' do
        patch :update, params: { id: target.prefixed_id, role_ids: [staff_role.prefixed_id] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(target.role_users.where(role: staff_role)).to exist
      end

      it 'forbids promoting an account to admin' do
        patch :update, params: { id: target.prefixed_id, role_ids: [admin_role.prefixed_id] }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(target.reload.spree_admin?(store)).to be(false)
      end

      # Removal is bounded like granting: a staff manager cannot strip the
      # owners' admin role and lock them out.
      it 'forbids removing a store owner' do
        owner = create(:admin_user)

        delete :destroy, params: { id: owner.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(owner.reload.spree_admin?(store)).to be(true)
      end

      it 'forbids clearing an owner\'s roles' do
        owner = create(:admin_user)

        patch :update, params: { id: owner.prefixed_id, role_ids: [] }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(owner.reload.spree_admin?(store)).to be(true)
      end

      it 'still removes a member it could have added' do
        delete :destroy, params: { id: target.prefixed_id }, as: :json

        expect(response).to have_http_status(:no_content)
        expect(target.role_users.where(role: store.roles)).not_to exist
      end

      it 'forbids assigning a role whose permissions exceed its own' do
        owner_role = create(:role, name: 'owner', permissions: Spree.permissions.grantable_keys(:store))

        patch :update, params: { id: target.prefixed_id, role_ids: [owner_role.prefixed_id] }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(target.role_users.where(role: owner_role)).not_to exist
      end
    end

    context 'authenticated as a super-admin JWT' do
      let(:headers) { bearer_headers }

      it 'allows granting the admin role' do
        patch :update, params: { id: target.prefixed_id, role_ids: [admin_role.prefixed_id] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(target.reload.spree_admin?(store)).to be(true)
      end

      it 'refuses removing the last admin' do
        Spree::RoleUser.where(role: admin_role).where.not(user: admin_user).destroy_all

        delete :destroy, params: { id: admin_user.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(admin_user.reload.spree_admin?(store)).to be(true)
      end

      it 'removes an admin while another remains' do
        other_admin = create(:admin_user)

        delete :destroy, params: { id: other_admin.prefixed_id }, as: :json

        expect(response).to have_http_status(:no_content)
        expect(other_admin.reload.spree_admin?(store)).to be(false)
      end
    end
  end
end
