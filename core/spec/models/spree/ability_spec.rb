require 'spec_helper'
require 'cancan/matchers'
require 'spree/testing_support/ability_helpers'
require 'spree/testing_support/bar_ability'

# Fake ability for testing registration of additional abilities
class FooAbility
  include CanCan::Ability

  def initialize(user)
    # allow anyone to perform index on Order
    can :index, Spree::Order
    # allow anyone to update an Order with id of 1
    can :update, Spree::Order do |order|
      order.id == 1
    end
  end
end

describe Spree::Ability do
  let(:user) { create(:user) }
  let(:ability) { Spree::Ability.new(user) }
  let(:token) { nil }

  before do
    user.spree_roles.clear
  end

  TOKEN = 'token123'

  after(:each) {
    Spree::Ability.abilities = Set.new
    user.spree_roles = []
  }

  context 'register_ability' do
    it 'should add the ability to the list of abilties' do
      Spree::Ability.register_ability(FooAbility)
      Spree::Ability.new(user).abilities.should_not be_empty
    end

    it 'should apply the registered abilities permissions' do
      Spree::Ability.register_ability(FooAbility)
      Spree::Ability.new(user).can?(:update, mock_model(Spree::Order, :id => 1)).should be_true
    end
  end

  context 'for general resource' do
    let(:resource) { Object.new }

    context 'with admin user' do
      before(:each) { user.stub(:has_spree_role?).and_return(true) }
      it_should_behave_like 'access granted'
      it_should_behave_like 'index allowed'
    end

    context 'with customer' do
      it_should_behave_like 'access denied'
      it_should_behave_like 'no index allowed'
    end
  end

  context 'for admin protected resources' do
    let(:resource) { Object.new }
    let(:resource_shipment) { Spree::Shipment.new }
    let(:resource_product) { Spree::Product.new }
    let(:resource_user) { Spree.user_class.new }
    let(:resource_order) { Spree::Order.new }
    let(:fakedispatch_user) { Spree.user_class.new }
    let(:fakedispatch_ability) { Spree::Ability.new(fakedispatch_user) }

    context 'with admin user' do
      it 'should be able to admin' do
        user.spree_roles << Spree::Role.find_or_create_by(name: 'admin')
        ability.should be_able_to :admin, resource
        ability.should be_able_to :index, resource_order
        ability.should be_able_to :show, resource_product
        ability.should be_able_to :create, resource_user
      end
    end

    context 'with fakedispatch user' do
      it 'should be able to admin on the order and shipment pages' do
        user.spree_roles << Spree::Role.find_or_create_by(name: 'bar')

        Spree::Ability.register_ability(BarAbility)

        ability.should_not be_able_to :admin, resource

        ability.should be_able_to :admin, resource_order
        ability.should be_able_to :index, resource_order
        ability.should_not be_able_to :update, resource_order
        # ability.should_not be_able_to :create, resource_order # Fails

        ability.should be_able_to :admin, resource_shipment
        ability.should be_able_to :index, resource_shipment
        ability.should be_able_to :create, resource_shipment

        ability.should_not be_able_to :admin, resource_product
        ability.should_not be_able_to :update, resource_product
        # ability.should_not be_able_to :show, resource_product # Fails

        ability.should_not be_able_to :admin, resource_user
        ability.should_not be_able_to :update, resource_user
        ability.should be_able_to :update, user
        # ability.should_not be_able_to :create, resource_user # Fails
        # It can create new users if is has access to the :admin, User!!

        # TODO change the Ability class so only users and customers get the extra premissions?

        Spree::Ability.remove_ability(BarAbility)
      end
    end

    context 'with customer' do
      it 'should not be able to admin' do
        ability.should_not be_able_to :admin, resource
        ability.should_not be_able_to :admin, resource_order
        ability.should_not be_able_to :admin, resource_product
        ability.should_not be_able_to :admin, resource_user
      end
    end
  end

  context 'as Guest User' do

    context 'for Country' do
      let(:resource) { Spree::Country.new }
      context 'requested by any user' do
        it_should_behave_like 'read only'
      end
    end

    context 'for OptionType' do
      let(:resource) { Spree::OptionType.new }
      context 'requested by any user' do
        it_should_behave_like 'read only'
      end
    end

    context 'for OptionValue' do
      let(:resource) { Spree::OptionType.new }
      context 'requested by any user' do
        it_should_behave_like 'read only'
      end
    end

    context 'for Order' do
      let(:resource) { Spree::Order.new }

      context 'requested by same user' do
        before(:each) { resource.user = user }
        it_should_behave_like 'access granted'
        it_should_behave_like 'no index allowed'
      end

      context 'requested by other user' do
        before(:each) { resource.user = Spree.user_class.new }
        it_should_behave_like 'create only'
      end

      context 'requested with proper token' do
        let(:token) { 'TOKEN123' }
        before(:each) { resource.stub :token => 'TOKEN123' }
        it_should_behave_like 'access granted'
        it_should_behave_like 'no index allowed'
      end

      context 'requested with inproper token' do
        let(:token) { 'FAIL' }
        before(:each) { resource.stub :token => 'TOKEN123' }
        it_should_behave_like 'create only'
      end
    end

    context 'for Product' do
      let(:resource) { Spree::Product.new }
      context 'requested by any user' do
        it_should_behave_like 'read only'
      end
    end

    context 'for ProductProperty' do
      let(:resource) { Spree::Product.new }
      context 'requested by any user' do
        it_should_behave_like 'read only'
      end
    end

    context 'for Property' do
      let(:resource) { Spree::Product.new }
      context 'requested by any user' do
        it_should_behave_like 'read only'
      end
    end

    context 'for State' do
      let(:resource) { Spree::State.new }
      context 'requested by any user' do
        it_should_behave_like 'read only'
      end
    end

    context 'for Taxons' do
      let(:resource) { Spree::Taxon.new }
      context 'requested by any user' do
        it_should_behave_like 'read only'
      end
    end

    context 'for Taxonomy' do
      let(:resource) { Spree::Taxonomy.new }
      context 'requested by any user' do
        it_should_behave_like 'read only'
      end
    end

    context 'for User' do
      context 'requested by same user' do
        let(:resource) { user }
        it_should_behave_like 'access granted'
        it_should_behave_like 'no index allowed'
      end
      context 'requested by other user' do
        let(:resource) { Spree.user_class.new }
        it_should_behave_like 'create only'
      end
    end

    context 'for Variant' do
      let(:resource) { Spree::Variant.new }
      context 'requested by any user' do
        it_should_behave_like 'read only'
      end
    end

    context 'for Zone' do
      let(:resource) { Spree::Zone.new }
      context 'requested by any user' do
        it_should_behave_like 'read only'
      end
    end

  end

end
