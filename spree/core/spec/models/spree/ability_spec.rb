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
  end

  describe '.register_ability' do
    let(:custom_ability_class) do
      Class.new do
        include CanCan::Ability

        def initialize(user)
          can :read, Spree::Order if user
        end
      end
    end

    after { Spree::Ability.remove_ability(custom_ability_class) }

    it 'merges registered ability rules into every ability' do
      Spree::Ability.register_ability(custom_ability_class)

      expect(Spree::Ability.new(create(:user))).to be_able_to :read, Spree::Order.new
    end
  end

  context 'as Guest User' do
    context 'for Country' do
      let(:resource) { Spree::Country.new }

      context 'requested by any user' do
        it_behaves_like 'read only'
      end
    end

    context 'for OptionType' do
      let(:resource) { Spree::OptionType.new }

      context 'requested by any user' do
        it_behaves_like 'read only'
      end
    end

    context 'for OptionValue' do
      let(:resource) { Spree::OptionType.new }

      context 'requested by any user' do
        it_behaves_like 'read only'
      end
    end

    context 'for Order' do
      let(:resource) { Spree::Order.new }

      context 'requested by same user' do
        before { resource.user = user }

        it_behaves_like 'access granted'
        it_behaves_like 'no index allowed'
      end

      context 'requested by other user' do
        before { resource.user = Spree.customer_class.new }

        it_behaves_like 'create only'
      end

      context 'requested with proper token' do
        let(:token) { 'TOKEN123' }

        before { allow(resource).to receive_messages token: token }

        it_behaves_like 'access granted'
        it_behaves_like 'no index allowed'
      end

      context 'requested with improper token' do
        let(:token) { 'FAIL' }

        before { allow(resource).to receive_messages token: token }

        it_behaves_like 'create only'
      end
    end

    context 'for Product' do
      let(:resource) { store.products.new }

      context 'requested by any user' do
        it_behaves_like 'read only'
      end
    end

    context 'for ProductProperty' do
      let(:resource) { store.products.new }

      context 'requested by any user' do
        it_behaves_like 'read only'
      end
    end

    context 'for Property' do
      let(:resource) { store.products.new }

      context 'requested by any user' do
        it_behaves_like 'read only'
      end
    end

    context 'for State' do
      let(:resource) { Spree::State.new }

      context 'requested by any user' do
        it_behaves_like 'read only'
      end
    end

    context 'for Taxons' do
      let(:resource) { Spree::Category.new }

      context 'requested by any user' do
        it_behaves_like 'read only'
      end
    end

    context 'for User' do
      context 'requested by same user' do
        let(:resource) { user }

        it_behaves_like 'access granted'
        it_behaves_like 'no index allowed'
      end

      context 'requested by other user' do
        let(:resource) { create(:user) }

        it_behaves_like 'create only'
      end
    end

    context 'for Variant' do
      let(:resource) { Spree::Variant.new }

      context 'requested by any user' do
        it_behaves_like 'read only'
      end
    end

    context 'for Zone' do
      let(:resource) { Spree::Zone.new }

      context 'requested by any user' do
        it_behaves_like 'read only'
      end
    end

    context 'for Address (IDOR vulnerability prevention)' do
      let(:guest_address) { create(:address, user_id: nil) }

      context 'with non-persisted guest user' do
        let(:guest_user) { Spree.customer_class.new }
        let(:guest_ability) { Spree::Ability.new(guest_user) }

        it 'cannot read guest addresses with nil user_id' do
          expect(guest_ability).not_to be_able_to :read, guest_address
        end

        it 'cannot edit guest addresses with nil user_id' do
          expect(guest_ability).not_to be_able_to :edit, guest_address
        end

        it 'cannot update guest addresses with nil user_id' do
          expect(guest_ability).not_to be_able_to :update, guest_address
        end

        it 'cannot destroy guest addresses with nil user_id' do
          expect(guest_ability).not_to be_able_to :destroy, guest_address
        end

        it 'cannot manage any address' do
          expect(guest_ability).not_to be_able_to :manage, guest_address
        end
      end

      context 'with persisted user' do
        let(:persisted_user) { create(:user) }
        let(:persisted_ability) { Spree::Ability.new(persisted_user) }
        let(:own_address) { create(:address, user_id: persisted_user.id) }

        it 'can manage own address' do
          expect(persisted_ability).to be_able_to :manage, own_address
        end

        it 'cannot manage guest addresses' do
          expect(persisted_ability).not_to be_able_to :manage, guest_address
        end

        it 'cannot manage other user addresses' do
          other_user = create(:user)
          other_address = create(:address, user_id: other_user.id)
          expect(persisted_ability).not_to be_able_to :manage, other_address
        end
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
