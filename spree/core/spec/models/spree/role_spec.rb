require 'spec_helper'

describe Spree::Role do
  let(:role) { create(:role) }
  let(:user) { create(:user) }
  # A non-store resource stands in for a marketplace vendor until that model
  # lands: what matters is that the role is owned by something else.
  let(:vendor_like) { create(:customer_group) }

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

    # Names are unique per owner, so another resource may legitimately call a
    # role "admin" — it must never be mistaken for the store super-role.
    it 'ignores a same-named role owned by something else' do
      foreign_admin = create(:role, name: 'admin', resource: vendor_like)

      admin_role = Spree::Role.default_admin_role(@default_store)

      expect(admin_role).not_to eq(foreign_admin)
      expect(admin_role).to be_staff
      expect(foreign_admin).not_to be_admin
      expect(foreign_admin).to be_mutable
    end

    # "admin" means everything in *this* store, so it cannot be one shared row.
    it 'gives each store its own' do
      other_store = create(:store)

      first = Spree::Role.default_admin_role(@default_store)
      second = Spree::Role.default_admin_role(other_store)

      expect(second).not_to eq(first)
      expect(second.resource).to eq(other_store)
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

  describe '#resource' do
    it 'reads its audience from the owning resource' do
      expect(build(:role).audience).to eq(:store)
      expect(build(:role)).to be_staff
      expect(build(:role, resource: vendor_like).audience).to eq(:customer_group)
      expect(build(:role, resource: vendor_like)).not_to be_staff
    end

    it 'is required' do
      expect(build(:role, resource: nil)).not_to be_valid
    end

    it 'cannot be changed once the role exists' do
      role = create(:role)
      role.resource = create(:store)

      expect(role).not_to be_valid
      expect(role.errors[:resource]).to be_present
    end

    it 'allows the same name under a different owner' do
      create(:role, name: 'Manager', resource: @default_store)

      expect(build(:role, name: 'Manager', resource: vendor_like)).to be_valid
      expect(build(:role, name: 'Manager', resource: create(:store))).to be_valid
    end

    it 'still rejects a duplicate name under one owner' do
      create(:role, name: 'Manager', resource: vendor_like)

      expect(build(:role, name: 'Manager', resource: vendor_like)).not_to be_valid
    end

    it 'scopes roles to the store back office' do
      staff_role = create(:role)
      other_role = create(:role, resource: vendor_like)

      expect(Spree::Role.staff).to include(staff_role)
      expect(Spree::Role.staff).not_to include(other_role)
      expect(Spree::Role.for_resource(vendor_like)).to eq([other_role])
    end
  end

  describe 'resource-bounded permissions' do
    before do
      Spree.permissions.register_resource(
        :products, group: :catalog, audiences: %i[customer_group], subjects: -> { [Spree::Product] }
      )
    end

    after { Spree.permissions.reset! }

    it 'allows a non-store role to hold keys its audience is granted' do
      expect(build(:role, resource: vendor_like, permissions: %w[write_products])).to be_valid
    end

    it 'refuses keys its audience is not granted' do
      role = build(:role, resource: vendor_like, permissions: %w[write_products write_settings])

      expect(role).not_to be_valid
      expect(role.errors[:permissions].join).to include('write_settings')
      expect(role.errors[:permissions].join).not_to include('write_products')
    end

    it 'leaves store roles unbounded' do
      expect(build(:role, permissions: %w[write_settings write_staff])).to be_valid
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
