require 'spec_helper'
require 'cancan/matchers'

RSpec.describe 'Permission Sets Integration with Ability', type: :model do
  let(:store) { create(:store) }

  before do
    # Reset permissions before each test
    Spree.permissions.reset!
  end

  after do
    # Reset permissions after each test
    Spree.permissions.reset!
  end

  describe 'role-based permissions' do
    let(:customer_service_permission_set) do
      Class.new(Spree::PermissionSets::Base) do
        def activate!
          can [:read, :admin], Spree::Order
          can [:read, :admin], Spree.user_class
        end
      end
    end

    let(:merchandiser_permission_set) do
      Class.new(Spree::PermissionSets::Base) do
        def activate!
          can :manage, Spree::Product
          can :manage, Spree::Variant
        end
      end
    end

    context 'user with single role' do
      let(:role) { create(:role, name: 'customer_service') }
      let(:user) { create(:user) }

      before do
        user.spree_roles << role
        Spree.permissions.assign(:customer_service, customer_service_permission_set)
      end

      it 'applies the permission sets for the role' do
        ability = Spree::Ability.new(user)

        expect(ability.can?(:read, Spree::Order)).to be true
        expect(ability.can?(:admin, Spree::Order)).to be true
        expect(ability.can?(:manage, Spree::Product)).to be false
      end
    end

    context 'user with multiple roles' do
      let(:cs_role) { create(:role, name: 'customer_service') }
      let(:merch_role) { create(:role, name: 'merchandiser') }
      let(:user) { create(:user) }

      before do
        user.spree_roles << cs_role
        user.spree_roles << merch_role
        Spree.permissions.assign(:customer_service, customer_service_permission_set)
        Spree.permissions.assign(:merchandiser, merchandiser_permission_set)
      end

      it 'combines permission sets from all roles' do
        ability = Spree::Ability.new(user)

        expect(ability.can?(:read, Spree::Order)).to be true
        expect(ability.can?(:manage, Spree::Product)).to be true
      end
    end

    context 'user with unconfigured role' do
      let(:role) { create(:role, name: 'unconfigured_role') }
      let(:user) { create(:user) }

      before do
        user.spree_roles << role
        # Don't configure any permission sets for this role
      end

      it 'falls back to legacy behavior' do
        ability = Spree::Ability.new(user)

        # Legacy behavior for regular users
        expect(ability.can?(:read, Spree::Product)).to be true
        expect(ability.can?(:create, Spree::Order)).to be true
        expect(ability.can?(:manage, Spree::Product)).to be false
      end
    end
  end

  describe 'default role' do
    let(:guest_user) { Spree.user_class.new }

    before do
      Spree.permissions.assign(:default, Spree::PermissionSets::DefaultCustomer)
    end

    it 'applies default permissions to non-persisted users' do
      ability = Spree::Ability.new(guest_user)

      expect(ability.can?(:read, Spree::Product)).to be true
      expect(ability.can?(:create, Spree::Order)).to be true
      expect(ability.can?(:manage, Spree::Product)).to be false
    end
  end

  describe 'admin role' do
    let(:admin_role) { Spree::Role.find_or_create_by!(name: 'admin') }
    let(:admin_user) { create(:admin_user) }

    before do
      admin_user.spree_roles << admin_role unless admin_user.spree_roles.include?(admin_role)
      Spree.permissions.assign(:admin, Spree::PermissionSets::SuperUser)
    end

    it 'applies super user permissions to admin users' do
      ability = Spree::Ability.new(admin_user)

      expect(ability.can?(:manage, :all)).to be true
    end
  end

  describe 'permission configuration API' do
    it 'allows configuring permissions like Solidus' do
      Spree.permissions.assign(:customer_service, [
        Spree::PermissionSets::OrderDisplay,
        Spree::PermissionSets::UserDisplay
      ])

      expect(Spree.permissions.permission_sets_for(:customer_service)).to include(
        Spree::PermissionSets::OrderDisplay,
        Spree::PermissionSets::UserDisplay
      )
    end

    it 'allows clearing permissions from a role' do
      Spree.permissions.assign(:customer_service, Spree::PermissionSets::OrderDisplay)
      Spree.permissions.clear(:customer_service)

      expect(Spree.permissions.permission_sets_for(:customer_service)).to be_empty
    end
  end
end
