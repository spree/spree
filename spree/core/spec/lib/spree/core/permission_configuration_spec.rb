require 'spec_helper'

RSpec.describe Spree::PermissionConfiguration do
  subject(:config) { described_class.new }

  # Create test permission set classes
  let(:permission_set_a) { Class.new(Spree::PermissionSets::Base) { def activate!; can :read, Spree::Order; end } }
  let(:permission_set_b) { Class.new(Spree::PermissionSets::Base) { def activate!; can :manage, Spree::Order; end } }
  let(:permission_set_c) { Class.new(Spree::PermissionSets::Base) { def activate!; can :read, Spree::Product; end } }

  describe '#assign' do
    it 'assigns a single permission set to a role' do
      config.assign(:customer_service, permission_set_a)

      expect(config.permission_sets_for(:customer_service)).to contain_exactly(permission_set_a)
    end

    it 'assigns multiple permission sets to a role' do
      config.assign(:customer_service, [permission_set_a, permission_set_b])

      expect(config.permission_sets_for(:customer_service)).to contain_exactly(permission_set_a, permission_set_b)
    end

    it 'adds to existing permission sets when called multiple times' do
      config.assign(:customer_service, permission_set_a)
      config.assign(:customer_service, permission_set_b)

      expect(config.permission_sets_for(:customer_service)).to contain_exactly(permission_set_a, permission_set_b)
    end

    it 'does not duplicate permission sets' do
      config.assign(:customer_service, permission_set_a)
      config.assign(:customer_service, permission_set_a)

      expect(config.permission_sets_for(:customer_service)).to contain_exactly(permission_set_a)
    end

    it 'normalizes role names to symbols' do
      config.assign('Customer_Service', permission_set_a)

      expect(config.permission_sets_for(:customer_service)).to contain_exactly(permission_set_a)
    end
  end

  describe '#clear' do
    it 'removes all permission sets from a role' do
      config.assign(:customer_service, [permission_set_a, permission_set_b])
      config.clear(:customer_service)

      expect(config.permission_sets_for(:customer_service)).to be_empty
    end

    it 'returns the removed permission sets' do
      config.assign(:customer_service, [permission_set_a, permission_set_b])

      expect(config.clear(:customer_service)).to contain_exactly(permission_set_a, permission_set_b)
    end

    it 'returns nil for non-existent roles' do
      expect(config.clear(:nonexistent)).to be_nil
    end
  end

  describe '#permission_sets_for' do
    it 'returns an empty array for non-configured roles' do
      expect(config.permission_sets_for(:unknown)).to eq([])
    end

    it 'returns the assigned permission sets' do
      config.assign(:admin, permission_set_a)

      expect(config.permission_sets_for(:admin)).to contain_exactly(permission_set_a)
    end

    it 'normalizes role names' do
      config.assign(:admin, permission_set_a)

      expect(config.permission_sets_for('ADMIN')).to contain_exactly(permission_set_a)
    end
  end

  describe '#permission_sets_for_roles' do
    it 'combines permission sets from multiple roles' do
      config.assign(:admin, permission_set_a)
      config.assign(:merchandiser, permission_set_b)

      expect(config.permission_sets_for_roles([:admin, :merchandiser])).to contain_exactly(permission_set_a, permission_set_b)
    end

    it 'deduplicates permission sets shared across roles' do
      config.assign(:admin, permission_set_a)
      config.assign(:merchandiser, [permission_set_a, permission_set_b])

      expect(config.permission_sets_for_roles([:admin, :merchandiser])).to contain_exactly(permission_set_a, permission_set_b)
    end

    it 'returns empty array when no roles have permission sets' do
      expect(config.permission_sets_for_roles([:unknown1, :unknown2])).to eq([])
    end
  end

  describe '#roles' do
    it 'returns all configured roles' do
      config.assign(:admin, permission_set_a)
      config.assign(:customer_service, permission_set_b)

      expect(config.roles).to contain_exactly(:admin, :customer_service)
    end

    it 'returns empty array when no roles are configured' do
      expect(config.roles).to eq([])
    end
  end

  describe '#role_configured?' do
    it 'returns true for configured roles' do
      config.assign(:admin, permission_set_a)

      expect(config.role_configured?(:admin)).to be true
    end

    it 'returns false for non-configured roles' do
      expect(config.role_configured?(:unknown)).to be false
    end

    it 'returns false for cleared roles' do
      config.assign(:admin, permission_set_a)
      config.clear(:admin)

      expect(config.role_configured?(:admin)).to be false
    end
  end

  describe '#reset!' do
    it 'clears all role permissions' do
      config.assign(:admin, permission_set_a)
      config.assign(:customer_service, permission_set_b)
      config.reset!

      expect(config.roles).to eq([])
    end
  end
end
