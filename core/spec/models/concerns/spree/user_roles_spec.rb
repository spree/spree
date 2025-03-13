require 'spec_helper'

module Spree
  class TestUser < Spree.base_class
    include Spree::UserRoles

    self.table_name = 'spree_users'
  end
end

describe Spree::UserRoles do
  let(:test_user) { Spree::TestUser.new }
  let(:role) { create(:role, name: 'test_role') }
  let(:admin_role) { create(:role, name: 'admin') }

  describe 'associations' do
    it 'defines role_users as a polymorphic association' do
      association = Spree::TestUser.reflect_on_association(:role_users)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:as]).to eq(:user)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it 'defines spree_roles through role_users' do
      association = Spree::TestUser.reflect_on_association(:spree_roles)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:through]).to eq(:role_users)
      expect(association.options[:source]).to eq(:role)
    end
  end

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
        expect(Spree::TestUser.spree_admin_created?).to be false
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
