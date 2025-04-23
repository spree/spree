require 'spec_helper'

describe Spree::UserManagement do
  let(:test_store) { create(:store) }
  let(:admin_user) { create(:admin_user) }
  let(:role) { create(:role, name: 'test_role') }

  describe 'instance methods' do
    describe '#add_user' do
      it 'adds a user to the resource with the default role' do
        test_store.add_user(admin_user)

        expect(test_store.users).to include(admin_user)
        expect(admin_user.has_spree_role?('admin', test_store)).to be true
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
    end

    describe '#default_user_role' do
      it 'returns the default admin role' do
        expect(test_store.default_user_role).to eq(Spree::Role.default_admin_role)
      end
    end
  end

  describe 'associations' do
    it 'has many role_users' do
      association = test_store.class.reflect_on_association(:role_users)
      expect(association.macro).to eq :has_many
      expect(association.options[:class_name]).to eq 'Spree::RoleUser'
      expect(association.options[:as]).to eq :resource
    end

    it 'has many users through role_users' do
      association = test_store.class.reflect_on_association(:users)
      expect(association.macro).to eq :has_many
      expect(association.options[:through]).to eq :role_users
      expect(association.options[:source]).to eq :user
      expect(association.options[:source_type]).to eq Spree.admin_user_class.to_s
    end

    it 'has many invitations' do
      association = test_store.class.reflect_on_association(:invitations)
      expect(association.macro).to eq :has_many
      expect(association.options[:class_name]).to eq 'Spree::Invitation'
    end
  end
end
