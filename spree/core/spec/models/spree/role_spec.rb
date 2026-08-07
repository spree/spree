require 'spec_helper'

describe Spree::Role do
  let(:role) { create(:role) }
  let(:user) { create(:user) }

  describe 'with users' do
    before do
      user.spree_roles << role
    end

    it 'can access users through the polymorphic association' do
      expect(role.users).to include(user)
    end
  end

  describe '.default_admin_role' do
    it 'returns the admin role, seeded immutable' do
      admin_role = Spree::Role.default_admin_role

      expect(admin_role.name).to eq('admin')
      expect(admin_role.read_attribute(:mutable)).to be false
    end
  end

  describe '#permissions' do
    it 'normalizes to a unique array of present strings' do
      role = build(:role, permissions: [:read_orders, 'read_orders', '', nil, 'write_products'])

      expect(role.permissions).to eq(%w[read_orders write_products])
    end

    it 'reads NULL column values as an empty array' do
      role = create(:role)
      role.update_column(:permissions, nil)

      expect(role.reload.permissions).to eq([])
    end

    it 'rejects unknown catalog keys' do
      role = build(:role, permissions: %w[read_orders write_bogus])

      expect(role).not_to be_valid
      expect(role.errors[:permissions].join).to include('write_bogus')
    end

    it 'rejects stored aliases' do
      expect(build(:role, permissions: %w[write_all])).not_to be_valid
    end
  end

  describe 'admin role protection' do
    let(:admin_role) { Spree::Role.default_admin_role }

    it 'is not mutable' do
      expect(admin_role.mutable?).to be false
    end

    it 'cannot be renamed' do
      admin_role.name = 'renamed'

      expect(admin_role).not_to be_valid
      expect(admin_role.errors[:name]).to be_present
    end

    it 'cannot change permissions' do
      admin_role.permissions = %w[read_orders]

      expect(admin_role).not_to be_valid
    end

    it 'cannot be destroyed' do
      expect(admin_role.destroy).to be false
      expect(admin_role.errors[:base]).to be_present
    end

    it 'stays protected by name even if the mutable flag is stale' do
      admin_role.update_column(:mutable, true)

      expect(admin_role.reload.mutable?).to be false
      expect(admin_role.destroy).to be false
    end
  end

  describe 'host-locked roles' do
    let(:locked_role) { create(:role, name: 'compliance', mutable: false, permissions: %w[read_orders]) }

    it 'cannot be renamed' do
      locked_role.name = 'renamed'

      expect(locked_role).not_to be_valid
    end

    it 'cannot change its description' do
      locked_role.description = 'edited'

      expect(locked_role).not_to be_valid
    end

    it 'cannot change permissions' do
      locked_role.permissions = %w[write_orders]

      expect(locked_role).not_to be_valid
    end

    it 'cannot be destroyed' do
      expect(locked_role.destroy).to be false
    end
  end

  describe 'mutable roles' do
    it 'can be renamed and re-permissioned' do
      role = create(:role, name: 'support', permissions: %w[read_orders])

      expect(role.update(name: 'helpdesk', permissions: %w[read_orders read_customers])).to be true
    end
  end

  describe '#can_be_deleted?' do
    it 'is true for an unreferenced mutable role' do
      expect(create(:role, name: 'support').can_be_deleted?).to be true
    end

    it 'is false while staff hold the role' do
      user.spree_roles << role

      expect(role.can_be_deleted?).to be false
      expect(role.destroy).to be false
    end

    it 'is false while a pending invitation references the role' do
      role = create(:role, name: 'support')
      create(:invitation, role: role)

      expect(role.can_be_deleted?).to be false
    end

    it 'is false for the admin role' do
      expect(Spree::Role.default_admin_role.can_be_deleted?).to be false
    end
  end
end
