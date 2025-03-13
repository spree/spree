require 'spec_helper'

class AdminUser < Spree.base_class
  self.table_name = 'spree_users'
  include Spree::UserRoles
end

describe Spree::RoleUser do
  describe 'with different user types' do
    let(:role) { create(:role, name: 'test_role') }
    let(:spree_user) { create(:user) }
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
end
