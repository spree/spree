require 'spec_helper'

describe Spree::UserManagement do
  let(:test_store) { create(:store) }
  let(:admin_user) { create(:admin_user) }
  # A role belongs to what it governs, so a grant on this store needs one here.
  let(:role) { create(:role, name: 'test_role', resource: test_store) }

  describe 'instance methods' do
    describe '#add_user' do
      it 'adds a user to the resource with the default role' do
        test_store.add_user(admin_user)

        expect(test_store.users).to include(admin_user)
        expect(admin_user.has_spree_role?('admin', test_store)).to be true
      end

      it 'refuses a role owned by another resource' do
        foreign_role = create(:role, name: 'elsewhere', resource: create(:store))

        expect { test_store.add_user(admin_user, foreign_role) }.to raise_error(ArgumentError)
      end

      it 'adds a user to the resource with a specified role' do
        test_store.add_user(admin_user, role)

        expect(test_store.users).to include(admin_user)
        expect(test_store.role_users.where(user: admin_user, role: role)).to exist
      end
    end

    describe '#remove_user' do
      before do
        test_store.add_user(admin_user)
      end

      it 'removes a user from the resource' do
        expect(test_store.users).to include(admin_user)

        test_store.remove_user(admin_user)

        expect(test_store.users.reload).not_to include(admin_user)
      end

      context 'with invitations still pending for the user' do
        # Sent before the account joined, as an invitation can't name a member.
        let!(:pending_invitation) do
          admin_user.role_users.destroy_all
          invitation = create(:invitation, resource: test_store, role: role, email: admin_user.email.upcase)
          test_store.add_user(admin_user)
          invitation
        end
        let!(:other_invitation) { create(:invitation, resource: test_store, role: role) }
        let!(:other_store_invitation) do
          other_store = create(:store)
          create(:invitation, resource: other_store, role: other_store.default_user_role, email: admin_user.email)
        end

        it 'revokes them, so they cannot rejoin by accepting one' do
          test_store.remove_user(admin_user)

          expect(Spree::Invitation.find_by(id: pending_invitation.id)).to be_nil
          expect(other_invitation.reload).not_to be_deleted
          expect(other_store_invitation.reload).not_to be_deleted
        end
      end
    end

    describe '#default_user_role' do
      it 'returns the store own admin role' do
        expect(test_store.default_user_role).to eq(Spree::Role.default_admin_role(test_store))
      end
    end
  end
end
