require 'spec_helper'

RSpec.describe Spree::ResourceUser, type: :model do
  let(:resource_user) { create(:resource_user) }
  let!(:admin_user) { create(:admin_user, :no_resource_user, spree_roles: []) }
  let(:store) { @default_store }
  let(:invitation) { create(:invitation, resource: store, roles: [create(:role)]) }

  describe 'Callbacks' do
    context 'after_create' do
      it 'sets roles from invitation when invitation is present' do
        role = create(:role)
        invitation = create(:invitation, roles: [role])

        resource_user = build(:resource_user,
                             invitation: invitation,
                             user: admin_user,
                             resource: invitation.resource)

        expect { resource_user.save! }.to change { admin_user.reload.spree_roles.count }.by(1)
        expect(admin_user.spree_roles).to include(role)
      end

      it 'does not set roles when invitation is not present' do
        resource_user = build(:resource_user, user: admin_user)

        expect { resource_user.save! }.not_to change { admin_user.reload.spree_roles.count }
      end
    end

    context 'after_destroy' do
      it 'revokes roles from invitation when invitation is present' do
        role = create(:role)
        invitation = create(:invitation, roles: [role])

        resource_user = create(:resource_user,
                              invitation: invitation,
                              user: admin_user,
                              resource: invitation.resource)

        expect(admin_user.reload.spree_roles).to include(role)
        expect { resource_user.destroy }.to change { admin_user.reload.spree_roles.count }.by(-1)
      end

      it 'does not revoke roles when invitation is not present' do
        role = create(:role)
        admin_user.spree_roles << role
        resource_user = create(:resource_user, user: admin_user)

        expect { resource_user.destroy }.not_to change { admin_user.reload.spree_roles.count }
      end
    end
  end
end
