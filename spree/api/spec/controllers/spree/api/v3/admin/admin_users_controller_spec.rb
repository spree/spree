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
end
