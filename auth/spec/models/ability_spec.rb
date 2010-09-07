require 'spec_helper'
require 'cancan/matchers'

# Fake ability for testing registration of additional abilities
class FooAbility
  include CanCan::Ability

  def initialize(user)
    # allow anyone to perform index on Order
    can :index, Order
  end
end

describe Ability do

  let(:user) { User.new }
  let(:ability) { Ability.new(user) }

  after(:each) { Ability.abilities = Set.new }
  context "register_ability" do
    it "should add the ability to the list of abilties" do
      Ability.register_ability(FooAbility)
      Ability.new(user).abilities.should_not be_empty
    end
    it "should apply the registered abilities permissions" do
      Ability.register_ability(FooAbility)
      Ability.new(user).can?(:index, Order).should be_true
    end
  end

  shared_examples_for "access granted" do
    it "should allow read" do
      ability.should be_able_to(:read, resource)
    end
    it "should allow create" do
      ability.should be_able_to(:create, resource)
    end
    it "should allow update" do
      ability.should be_able_to(:update, resource)
    end
  end

  shared_examples_for "access denied" do
    it "should not allow read" do
      ability.should_not be_able_to(:read, resource)
    end
    it "should not allow create" do
      ability.should_not be_able_to(:create, resource)
    end
    it "should not allow update" do
      ability.should_not be_able_to(:update, resource)
    end
  end

  shared_examples_for "index allowed" do
    it "should allow index" do
      ability.should be_able_to(:index, resource)
    end
  end

  shared_examples_for "no index allowed" do
    it "should not allow index" do
      ability.should_not be_able_to(:index, resource)
    end
  end

  shared_examples_for "create only" do
    it "should allow create" do
      ability.should be_able_to(:create, resource)
    end
    it "should not allow read" do
      ability.should_not be_able_to(:read, resource)
    end
    it "should not allow update" do
      ability.should_not be_able_to(:update, resource)
    end
    it "should not allow index" do
      ability.should_not be_able_to(:index, resource)
    end
  end

  shared_examples_for "read only" do
    it "should not allow create" do
      ability.should_not be_able_to(:create, resource)
    end
    it "should allow read" do
      ability.should be_able_to(:read, resource)
    end
    it "should not allow update" do
      ability.should_not be_able_to(:update, resource)
    end
    it "should allow index" do
      ability.should be_able_to(:index, resource)
    end
  end

  context "for general resource" do
    let(:resource) { Object.new }
    context "with admin user" do
      before(:each) { user.stub(:has_role?).and_return(true) }
      it_should_behave_like "access granted"
      it_should_behave_like "index allowed"
    end
    context "with customer" do
      it_should_behave_like "access denied"
      it_should_behave_like "no index allowed"
    end
  end

  context "for admin protected resources" do
    let(:resource) { Object.new }
    context "with admin user" do
      before(:each) { user.stub(:has_role?).and_return(true) }
      it "should be able to admin" do
        ability.should be_able_to :admin, resource
      end
    end
    context "with customer" do
      it "should not be able to admin" do
        ability.should_not be_able_to :admin, resource
      end
    end
  end

  context "for User" do
    context "requested by same user" do
      let(:resource) { user }
      it_should_behave_like "access granted"
      it_should_behave_like "no index allowed"
    end
    context "requested by other user" do
      let(:resource) { User.new }
      it_should_behave_like "create only"
    end
  end

  context "for Order" do
    let(:resource) { Order.new }
    context "requested by same user" do
      before(:each) { resource.user = user }
      it_should_behave_like "access granted"
      it_should_behave_like "no index allowed"
    end
    context "requested by other user" do
      before(:each) { resource.user = User.new }
      it_should_behave_like "create only"
    end
  end

  context "for Product" do
    let(:resource) { Product.new }
    context "requested by any user" do
      it_should_behave_like "read only"
    end
  end

  context "for Taxons" do
    let(:resource) { Taxon.new }
    context "requested by any user" do
      it_should_behave_like "read only"
    end
  end
end
