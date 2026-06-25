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

  describe 'Callbacks' do
    describe 'before_validation :set_default_resource' do
      it 'sets the resource to the current store if it is not set' do
        role_user = described_class.new(role: role, user: spree_user)
        expect(role_user.valid?).to be_truthy

        expect(role_user.resource).to eq(Spree::Store.current)
      end
    end

    describe 'before_validation :set_store' do
      let(:store) { create(:store) }

      it 'sets the store from a store resource' do
        role_user = described_class.new(role: role, user: spree_user, resource: store)
        expect(role_user.valid?).to be_truthy

        expect(role_user.store).to eq(store)
      end

      it 'derives the store from a resource that responds to #store' do
        resource = create(:wishlist, store: store)
        role_user = described_class.new(role: role, user: spree_user, resource: resource)
        expect(role_user.valid?).to be_truthy

        expect(role_user.store).to eq(store)
      end

      it 'defaults to the current store when no store can be derived' do
        role_user = described_class.new(role: role, user: spree_user)
        expect(role_user.valid?).to be_truthy

        expect(role_user.store).to eq(Spree::Store.current)
      end
    end
  end

  describe '#name' do
    it 'returns the name of the user' do
      role_user = described_class.new(role: role, user: spree_user)

      expect(role_user.name).to eq(spree_user.name)
    end
  end
end
