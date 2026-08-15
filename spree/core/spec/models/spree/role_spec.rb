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
      admin_role = Spree::Role.default_admin_role(@default_store)

      expect(admin_role.name).to eq('admin')
      expect(admin_role.read_attribute(:mutable)).to be false
    end

    # "admin" means everything in *this* store, so it cannot be one shared row.
    it 'gives each store its own' do
      other_store = create(:store)

      first = Spree::Role.default_admin_role(@default_store)
      second = Spree::Role.default_admin_role(other_store)

      expect(second).not_to eq(first)
      expect(second.store).to eq(other_store)
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

  describe '#audience' do
    it 'defaults to staff' do
      expect(build(:role).audience).to eq('staff')
      expect(build(:role)).to be_staff
    end

    it 'rejects a blank audience' do
      expect(build(:role, audience: nil)).not_to be_valid
    end

    it 'rejects an unknown audience' do
      expect(build(:role, audience: 'wizard')).not_to be_valid
    end

    it 'cannot be changed once the role exists' do
      role = create(:role, audience: 'staff')
      role.audience = 'vendor'

      expect(role).not_to be_valid
      expect(role.errors[:audience]).to be_present
    end

    it 'allows the same name in each audience' do
      create(:role, name: 'Manager', audience: 'staff')

      expect(build(:role, name: 'Manager', audience: 'vendor')).to be_valid
    end

    it 'still rejects a duplicate name within one audience' do
      create(:role, name: 'Manager', audience: 'vendor')

      expect(build(:role, name: 'Manager', audience: 'vendor')).not_to be_valid
    end

    it 'allows the same name in another store' do
      create(:role, name: 'Manager', store: @default_store)

      expect(build(:role, name: 'Manager', store: create(:store))).to be_valid
    end

    it 'scopes roles by audience' do
      staff_role = create(:role, audience: 'staff')
      vendor_role = create(:role, audience: 'vendor')

      expect(Spree::Role.staff).to include(staff_role)
      expect(Spree::Role.staff).not_to include(vendor_role)
      expect(Spree::Role.vendor).to include(vendor_role)
    end
  end

  describe 'audience-bounded permissions' do
    it 'allows a vendor role to hold vendor-grantable keys' do
      expect(build(:role, audience: 'vendor', permissions: %w[write_products write_orders])).to be_valid
    end

    it 'refuses operator-only keys on a vendor role' do
      role = build(:role, audience: 'vendor', permissions: %w[write_products write_settings])

      expect(role).not_to be_valid
      expect(role.errors[:permissions].join).to include('write_settings')
      expect(role.errors[:permissions].join).not_to include('write_products')
    end

    it 'leaves staff roles unbounded' do
      expect(build(:role, audience: 'staff', permissions: %w[write_settings write_staff])).to be_valid
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
