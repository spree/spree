require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::InvitationsController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  let!(:admin_role) { Spree::Role.default_admin_role }
  let(:staff_role) { create(:role, name: 'staff') }

  before { request.headers.merge!(headers) }

  describe 'POST #create — role-grant privilege escalation' do
    # The admin-role grant is rejected before the inviter is even resolved, so
    # a secret API key (which has no human inviter) is the strictest principal
    # to assert the guard against.
    context 'authenticated via a secret API key (no human identity)' do
      let(:caller_key) { create(:api_key, :secret, store: store, scopes: ['write_settings']) }
      let(:headers) { { 'x-spree-api-key' => caller_key.plaintext_token } }

      it 'forbids inviting straight into the admin role' do
        expect {
          post :create, params: { email: 'attacker@evil.com', role_id: admin_role.prefixed_id }, as: :json
        }.not_to change(Spree::Invitation, :count)

        expect(response).to have_http_status(:forbidden)
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

      let(:inviter_set) do
        Class.new(Spree::PermissionSets::Base) do
          def activate!
            can :manage, Spree::Invitation
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

      before { Spree.permissions.assign(:staff, inviter_set) }

      it 'forbids a non-admin from inviting into the admin role' do
        expect {
          post :create, params: { email: 'attacker@evil.com', role_id: admin_role.prefixed_id }, as: :json
        }.not_to change(Spree::Invitation, :count)

        expect(response).to have_http_status(:forbidden)
      end

      it 'allows inviting with a non-admin role' do
        expect {
          post :create, params: { email: 'new-staff@example.com', role_id: staff_role.prefixed_id }, as: :json
        }.to change(Spree::Invitation, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(Spree::Invitation.last.role).to eq(staff_role)
      end

      it 'forbids inviting into a SuperUser-equivalent custom role' do
        owner_role = create(:role, name: 'owner')
        Spree.permissions.assign(:owner, Spree::PermissionSets::SuperUser)

        expect {
          post :create, params: { email: 'attacker@evil.com', role_id: owner_role.prefixed_id }, as: :json
        }.not_to change(Spree::Invitation, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'authenticated as a super-admin JWT' do
      let(:headers) { bearer_headers }

      it 'allows inviting with the admin role' do
        expect {
          post :create, params: { email: 'co-admin@example.com', role_id: admin_role.prefixed_id }, as: :json
        }.to change(Spree::Invitation, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(Spree::Invitation.last.role).to eq(admin_role)
      end
    end
  end
end
