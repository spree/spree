require 'spec_helper'
require 'cancan/matchers'
require 'spree/testing_support/ability_helpers'

describe Spree::Ability, type: :model do
  let(:store) { @default_store }
  let(:user) { build(:user) }
  let(:ability) { Spree::Ability.new(user) }
  let(:token) { nil }

  context 'for general resource' do
    let(:resource) { Object.new }

    context 'with admin user' do
      let(:user) { create(:admin_user) }

      it_behaves_like 'access granted'
      it_behaves_like 'index allowed'
    end

    context 'with customer' do
      it_behaves_like 'access denied'
      it_behaves_like 'no index allowed'
    end
  end

  context 'for admin protected resources' do
    let(:resource) { Object.new }
    let(:resource_product) { store.products.new }
    let(:resource_user) { create(:user) }
    let(:resource_order) { create(:order, customer: resource_user) }

    context 'with admin user' do
      context 'admin user role' do
        let(:user) { create(:admin_user) }

        it 'is able to admin' do
          expect(ability).to be_able_to :admin, resource
          expect(ability).to be_able_to :index, resource_order
          expect(ability).to be_able_to :show, resource_product
          expect(ability).to be_able_to :create, resource_user
        end
      end

      context 'admin user class with no role rows (spree_admin? fallback)' do
        let(:user) { Spree::DummyModel.create(name: 'admin') }

        before do
          @original_admin_user_class = Spree.admin_user_class(constantize: false)
          Spree.admin_user_class = 'Spree::DummyModel'
          allow(user).to receive(:spree_admin?).and_return(true)
        end

        after { Spree.admin_user_class = @original_admin_user_class }

        it 'is able to admin' do
          expect(ability).to be_able_to :admin, resource
          expect(ability).to be_able_to :index, resource_order
          expect(ability).to be_able_to :show, resource_product
          expect(ability).to be_able_to :create, resource_user
        end
      end
    end

    context 'with customer' do
      it 'is not able to admin' do
        expect(ability).not_to be_able_to :admin, resource
        expect(ability).not_to be_able_to :admin, resource_order
        expect(ability).not_to be_able_to :admin, resource_product
        expect(ability).not_to be_able_to :admin, resource_user
      end

      it 'is not able to admin even with an admin role assignment' do
        user.save!
        user.spree_roles << Spree::Role.default_admin_role

        expect(Spree::Ability.new(user)).not_to be_able_to :admin, resource
      end
    end
  end

  describe 'staff permissions from catalog keys' do
    let(:admin) { create(:admin_user, :without_admin_role) }
    let(:staff_ability) { Spree::Ability.new(admin, store: store) }

    context 'with a role granting a read key' do
      before do
        admin.role_users.create!(role: create(:role, name: 'viewer', permissions: %w[read_orders]), resource: store)
      end

      it 'grants read and admin on the resource subjects' do
        expect(staff_ability).to be_able_to :read, Spree::Order.new
        expect(staff_ability).to be_able_to :admin, Spree::Order.new
        expect(staff_ability).not_to be_able_to :update, Spree::Order.new
      end

      it 'does not grant other resources' do
        expect(staff_ability).not_to be_able_to :read, store.products.new
      end

      it 'reports the expanded permission keys' do
        expect(staff_ability.permission_keys).to eq(%w[read_orders])
      end
    end

    context 'with a role granting a write key' do
      before do
        admin.role_users.create!(role: create(:role, name: 'manager', permissions: %w[write_orders]), resource: store)
      end

      it 'grants manage on the resource subjects' do
        expect(staff_ability).to be_able_to :manage, Spree::Order.new
        expect(staff_ability).to be_able_to :read, Spree::Order.new
      end

      it 'reports write and implied read keys' do
        expect(staff_ability.permission_keys).to eq(%w[read_orders write_orders])
      end
    end

    context 'with multiple roles' do
      before do
        admin.role_users.create!(role: create(:role, name: 'support', permissions: %w[read_orders]), resource: store)
        admin.role_users.create!(role: create(:role, name: 'merch', permissions: %w[write_products]), resource: store)
      end

      it 'combines keys from all roles' do
        expect(staff_ability).to be_able_to :read, Spree::Order.new
        expect(staff_ability).to be_able_to :manage, store.products.new
        expect(staff_ability).not_to be_able_to :update, Spree::Order.new
      end
    end

    context 'with a role granting no keys' do
      before do
        admin.role_users.create!(role: create(:role, name: 'empty'), resource: store)
      end

      it 'grants only the staff baseline' do
        expect(staff_ability).not_to be_able_to :read, Spree::Order.new
        expect(staff_ability).not_to be_able_to :manage, store.products.new
        expect(staff_ability).to be_able_to :read, Spree::Country.new
        expect(staff_ability).to be_able_to :read, Spree::State.new
        expect(staff_ability).to be_able_to :read, store
      end
    end

    context 'with the admin role' do
      before do
        admin.role_users.create!(role: Spree::Role.default_admin_role, resource: store)
      end

      it 'grants everything and reports the full catalog' do
        expect(staff_ability).to be_able_to :manage, :all
        expect(staff_ability.permission_keys).to eq(Spree.permissions.catalog_keys)
      end
    end

    context 'with overlapping keys across roles' do
      before do
        admin.role_users.create!(role: create(:role, name: 'viewer', permissions: %w[read_orders]), resource: store)
        admin.role_users.create!(role: create(:role, name: 'manager', permissions: %w[write_orders read_orders]), resource: store)
      end

      it 'deduplicates into one expanded key set' do
        expect(staff_ability.permission_keys).to eq(%w[read_orders write_orders])
        expect(staff_ability).to be_able_to :manage, Spree::Order.new
      end
    end

    context 'with roles held on different stores' do
      let(:store_b) { create(:store) }

      before do
        admin.role_users.create!(role: create(:role, name: 'a_orders', permissions: %w[write_orders]), resource: store)
        admin.role_users.create!(role: create(:role, name: 'b_products', permissions: %w[write_products]), resource: store_b)
      end

      it 'activates only the current store assignments' do
        expect(staff_ability).to be_able_to :manage, Spree::Order.new
        expect(staff_ability).not_to be_able_to :read, store.products.new
        expect(staff_ability.permission_keys).to eq(%w[read_orders write_orders])
      end

      it 'flips with the store context' do
        ability_b = Spree::Ability.new(admin, store: store_b)

        expect(ability_b).to be_able_to :manage, store.products.new
        expect(ability_b).not_to be_able_to :read, Spree::Order.new
        expect(ability_b.permission_keys).to eq(%w[read_products write_products])
      end
    end

    context 'as admin on one store and limited staff on another' do
      let(:store_b) { create(:store) }

      before do
        admin.role_users.create!(role: Spree::Role.default_admin_role, resource: store)
        admin.role_users.create!(role: create(:role, name: 'b_viewer', permissions: %w[read_orders]), resource: store_b)
      end

      it 'does not leak admin authority into the limited store' do
        expect(staff_ability).to be_able_to :manage, :all

        ability_b = Spree::Ability.new(admin, store: store_b)
        expect(ability_b).not_to be_able_to :manage, :all
        expect(ability_b).not_to be_able_to :update, Spree::Order.new
        expect(ability_b.permission_keys).to eq(%w[read_orders])
      end
    end

    context 'with the same role assigned on two stores' do
      let(:store_b) { create(:store) }
      let(:role) { create(:role, name: 'shared', permissions: %w[write_orders]) }

      before do
        admin.role_users.create!(role: role, resource: store)
        admin.role_users.create!(role: role, resource: store_b)
      end

      it 'grants the same keys on each store' do
        expect(staff_ability.permission_keys).to eq(%w[read_orders write_orders])
        expect(Spree::Ability.new(admin, store: store_b).permission_keys).to eq(%w[read_orders write_orders])
      end
    end

    # A marketplace vendor's staff hold roles scoped to the vendor, which binds
    # to the vendor's store. Store-admin authority must come only from
    # store-resourced assignments, or a vendor picker would inherit the whole
    # store — including, for an `admin`-named vendor role, full access.
    context 'with an assignment scoped to a non-store resource' do
      let(:vendor_like) { Spree::DummyModel.create!(name: 'Vendor A') }

      it 'grants nothing in the store admin' do
        admin.role_users.create!(
          role: create(:role, name: 'vendor_catalog', permissions: %w[write_products]),
          resource: vendor_like
        )

        expect(staff_ability).not_to be_able_to :manage, store.products.new
        expect(staff_ability).not_to be_able_to :read, store.products.new
        expect(staff_ability.permission_keys).to eq([])
      end

      it 'does not confer full access through an admin-named role' do
        admin.role_users.create!(role: Spree::Role.default_admin_role, resource: vendor_like)

        expect(staff_ability).not_to be_able_to :manage, :all
        expect(staff_ability.permission_keys).to eq([])
      end
    end

    context 'with stale keys the catalog no longer knows' do
      before do
        role = create(:role, name: 'stale', permissions: %w[read_orders])
        role.update_column(:permissions, %w[read_orders write_bogus])
        admin.role_users.create!(role: role, resource: store)
      end

      it 'activates the known keys and drops the rest' do
        expect(staff_ability).to be_able_to :read, Spree::Order.new
        expect(staff_ability.permission_keys).to eq(%w[read_orders])
      end
    end
  end

  describe 'shared customer/admin user class' do
    # The install generator falls back to `user_class` for the admin user class
    # when a host provides only one — persisted customers are then admin-class
    # principals and resolve staff roles like any admin user.
    around do |example|
      original = Spree.admin_user_class(constantize: false)
      Spree.admin_user_class = Spree.customer_class.to_s
      example.run
    ensure
      Spree.admin_user_class = original
    end

    it 'grants nothing to customers holding no roles' do
      customer = create(:user)
      shared_ability = Spree::Ability.new(customer, store: store)

      expect(shared_ability).not_to be_able_to :manage, Spree::Order.new
      expect(shared_ability.permission_keys).to eq([])
    end

    it 'resolves staff roles for persisted customers' do
      manager = create(:user)
      manager.role_users.create!(
        role: create(:role, name: 'shared_manager', permissions: %w[write_orders]),
        resource: store
      )
      shared_ability = Spree::Ability.new(manager, store: store)

      expect(shared_ability).to be_able_to :manage, Spree::Order.new
    end
  end

  context 'as a customer or guest principal' do
    it 'has no rules at all — the Store API authorizes by ownership scoping' do
      customer_ability = Spree::Ability.new(create(:user))
      guest_ability = Spree::Ability.new(nil)

      [customer_ability, guest_ability].each do |ability|
        expect(ability).not_to be_able_to :read, store.products.new
        expect(ability).not_to be_able_to :create, Spree::Order
        expect(ability.permission_keys).to eq([])
      end
    end
  end

  context 'role resolution uses the store of a role user' do
    let(:admin) { create(:admin_user, :without_admin_role) }
    let(:store_a) { @default_store }
    let(:store_b) { create(:store) }

    before do
      admin.role_users.create!(role: Spree::Role.default_admin_role, resource: store_a)
    end

    it "grants authority on the role assignment's store" do
      ability = Spree::Ability.new(admin, store: store_a)
      expect(ability).to be_able_to :manage, Spree::Product.new
    end

    it 'does not grant authority on a different store' do
      ability = Spree::Ability.new(admin, store: store_b)
      expect(ability).not_to be_able_to :manage, Spree::Product.new
    end
  end
end
