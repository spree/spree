require 'spec_helper'

describe Spree::UserRoles do
  let(:role) { create(:role, name: 'test_role') }
  let(:admin_role) { create(:role, name: 'admin') }

  describe 'instance methods' do
    let(:user) { create(:user) }

    describe '#has_spree_role?' do
      it 'returns true if the user has the role' do
        user.spree_roles << role
        expect(user.has_spree_role?('test_role')).to be true
      end

      it 'returns false if the user does not have the role' do
        expect(user.has_spree_role?('test_role')).to be false
      end
    end

    describe '#spree_admin?' do
      it 'returns true if the user has the admin role' do
        user.spree_roles << admin_role
        expect(user.spree_admin?).to be true
      end

      it 'returns false if the user does not have the admin role' do
        expect(user.spree_admin?).to be false
      end
    end
  end

  describe 'class methods' do
    describe '.spree_admin_created?' do
      it 'returns true if an admin user exists' do
        user = create(:user)
        user.spree_roles << admin_role
        expect(user.class.spree_admin_created?).to be true
      end

      it 'returns false if no admin user exists' do
        Spree::RoleUser.where(role: Spree::Role.find_by(name: 'admin')).destroy_all
        expect(Spree::LegacyUser.spree_admin_created?).to be false
      end
    end
  end

  describe 'with real users' do
    let(:user) { create(:user) }

    it 'can add roles to a user' do
      user.spree_roles << role
      expect(user.has_spree_role?('test_role')).to be true
    end

    it 'can check if a user is an admin' do
      user.spree_roles << admin_role
      expect(user.spree_admin?).to be true
    end

    it 'creates role_user records with the correct user_type' do
      user.spree_roles << role
      role_user = Spree::RoleUser.last
      expect(role_user.user).to eq(user)
      expect(role_user.user_type).to eq(user.class.to_s)
    end
  end
end
