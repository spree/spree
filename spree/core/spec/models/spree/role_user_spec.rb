require 'spec_helper'

class AdminUser < Spree.base_class
  self.table_name = 'spree_users'
  include Spree::UserRoles
end

describe Spree::RoleUser do
  let(:role) { create(:role, name: 'test_role') }
  let(:spree_user) { create(:user) }

  describe 'with different user types' do
    let(:admin_user) { AdminUser.new(id: 99) }

    it 'can associate with different user types' do
      spree_role_user = described_class.create!(role: role, user: spree_user)
      admin_role_user = described_class.create!(role: role, user: admin_user)

      expect(spree_user).not_to eq(admin_user)

      expect(spree_role_user.user).to eq(spree_user)
      expect(spree_role_user.user_type).to eq(spree_user.class.to_s)

      expect(admin_role_user.user).to eq(admin_user)
      expect(admin_role_user.user_type).to eq('AdminUser')
    end
  end

  # An assignment carries no copy of where it applies — the role says.
  describe '#resource' do
    it 'comes from the role' do
      other_store = create(:store)
      role_user = described_class.new(role: create(:role, resource: other_store), user: spree_user)

      expect(role_user.resource).to eq(other_store)
    end
  end

  describe 'uniqueness' do
    it 'allows a user to hold a role once' do
      described_class.create!(role: role, user: spree_user)

      expect(described_class.new(role: role, user: spree_user)).not_to be_valid
    end

    it 'allows the same user to hold a role owned by another resource' do
      described_class.create!(role: role, user: spree_user)
      other_role = create(:role, name: 'test_role', resource: create(:store))

      expect(described_class.new(role: other_role, user: spree_user)).to be_valid
    end
  end

  describe '#name' do
    it 'returns the name of the user' do
      role_user = described_class.new(role: role, user: spree_user)

      expect(role_user.name).to eq(spree_user.name)
    end
  end
end
