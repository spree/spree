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
      u.role_users.create!(role: staff_role, resource: store)
    end
  end

  before { request.headers.merge!(headers) }

  describe 'PATCH #update — role-grant privilege escalation' do
    context 'authenticated via a secret API key (no human identity)' do
      let(:caller_key) { create(:api_key, :secret, store: store, scopes: ['write_settings']) }
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
        expect(target.role_users.where(resource: store, role: other_role)).to exist
      end
    end

    context 'authenticated as a non-admin staff JWT' do
      around do |example|
        saved = Spree.permissions.dup
        Spree.permissions.reset!
        example.run
      ensure
        Spree.permissions.replace(saved)
      end

      let(:user_manager_set) do
        Class.new(Spree::PermissionSets::Base) do
          def activate!
            can :manage, Spree.admin_user_class
            can [:read, :admin], Spree::Role
          end
        end
      end

      let(:staff_admin) do
        create(:admin_user, :without_admin_role).tap { |u| u.role_users.create!(role: staff_role, resource: store) }
      end
      let(:headers) do
        api_key_headers.merge('Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(staff_admin, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}")
      end

      before do
        Spree.permissions.assign(:staff, user_manager_set)
      end

      it 'forbids a non-admin from promoting an account to admin' do
        patch :update, params: { id: target.prefixed_id, role_ids: [admin_role.prefixed_id] }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(target.reload.spree_admin?(store)).to be(false)
      end

      it 'forbids assigning any role without role-management authority' do
        expect {
          patch :update, params: { id: target.prefixed_id, role_ids: [staff_role.prefixed_id] }, as: :json
        }.not_to change { target.role_users.where(resource: store).count }

        expect(response).to have_http_status(:forbidden)
      end

      # Unknown role ids must not slip the management gate: the reconciliation
      # would otherwise strip the target's existing roles.
      it 'forbids a role mutation with unresolved role ids' do
        expect {
          patch :update, params: { id: target.prefixed_id, role_ids: ['role_nonexistent'] }, as: :json
        }.not_to change { target.role_users.where(resource: store).count }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'authenticated as a staff JWT holding RoleManagement' do
      around do |example|
        saved = Spree.permissions.dup
        Spree.permissions.reset!
        example.run
      ensure
        Spree.permissions.replace(saved)
      end

      let(:role_manager_set) do
        Class.new(Spree::PermissionSets::Base) do
          def activate!
            can :manage, Spree.admin_user_class
            can :manage, Spree::RoleUser
            can [:read, :admin], Spree::Role
          end
        end
      end

      let(:staff_admin) do
        create(:admin_user, :without_admin_role).tap { |u| u.role_users.create!(role: staff_role, resource: store) }
      end
      let(:headers) do
        api_key_headers.merge('Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(staff_admin, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}")
      end

      before { Spree.permissions.assign(:staff, role_manager_set) }

      it 'allows assigning a non-privileged role' do
        patch :update, params: { id: target.prefixed_id, role_ids: [staff_role.prefixed_id] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(target.role_users.where(resource: store, role: staff_role)).to exist
      end

      it 'forbids assigning a SuperUser-equivalent role it does not hold' do
        owner_role = create(:role, name: 'owner')
        Spree.permissions.assign(:owner, Spree::PermissionSets::SuperUser)

        patch :update, params: { id: target.prefixed_id, role_ids: [owner_role.prefixed_id] }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(target.role_users.where(resource: store, role: owner_role)).not_to exist
      end
    end

    context 'authenticated as a super-admin JWT' do
      let(:headers) { bearer_headers }

      it 'allows granting the admin role' do
        patch :update, params: { id: target.prefixed_id, role_ids: [admin_role.prefixed_id] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(target.reload.spree_admin?(store)).to be(true)
      end
    end
  end

  describe 'last-admin lockout guard' do
    # A scope-limited API-key principal holds no roles of its own (unlike a
    # human JWT admin, who — via the factory default — would themselves hold
    # the admin role on this store and quietly count as "another admin").
    let(:caller_key) { create(:api_key, :secret, store: store, scopes: ['write_settings']) }
    let(:headers) { { 'x-spree-api-key' => caller_key.plaintext_token } }

    context 'when the target is the store\'s only admin' do
      let!(:sole_admin) do
        create(:admin_user, :without_admin_role).tap { |u| u.role_users.create!(role: admin_role, resource: store) }
      end

      it 'forbids destroying the account' do
        delete :destroy, params: { id: sole_admin.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(sole_admin.role_users.where(resource: store, role: admin_role)).to exist
      end

      it 'forbids stripping the admin role via update' do
        other_role = create(:role, name: 'support')

        patch :update, params: { id: sole_admin.prefixed_id, role_ids: [other_role.prefixed_id] }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(sole_admin.role_users.where(resource: store, role: admin_role)).to exist
        expect(sole_admin.role_users.where(resource: store, role: other_role)).not_to exist
      end

      it 'still allows updating identity fields without touching roles' do
        patch :update, params: { id: sole_admin.prefixed_id, first_name: 'Ada' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(sole_admin.reload.first_name).to eq('Ada')
      end
    end

    context 'when another admin exists for the store' do
      let!(:sole_admin) do
        create(:admin_user, :without_admin_role).tap { |u| u.role_users.create!(role: admin_role, resource: store) }
      end
      let!(:second_admin) do
        create(:admin_user, :without_admin_role).tap { |u| u.role_users.create!(role: admin_role, resource: store) }
      end

      it 'allows destroying one of them' do
        delete :destroy, params: { id: sole_admin.prefixed_id }, as: :json

        expect(response).to have_http_status(:no_content)
        expect(sole_admin.role_users.where(resource: store)).not_to exist
      end

      it 'allows stripping the admin role from one of them via update' do
        other_role = create(:role, name: 'support')

        patch :update, params: { id: sole_admin.prefixed_id, role_ids: [other_role.prefixed_id] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(sole_admin.role_users.where(resource: store, role: admin_role)).not_to exist
      end
    end

    context 'when the target does not currently hold the admin role' do
      it 'does not block destroying a non-admin staff member' do
        delete :destroy, params: { id: target.prefixed_id }, as: :json

        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
