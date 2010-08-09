require 'spec_helper'
require 'cancan/matchers'

describe Ability do

  let(:user) { User.new }
  let(:ability) { Ability.new(user) }
  let(:token) { "" }

  shared_examples_for "access granted" do
    it "should allow read" do
      ability.should be_able_to(:read, resource, token)
    end
    it "should allow create" do
      ability.should be_able_to(:create, resource, token)
    end
    it "should allow update" do
      ability.should be_able_to(:update, resource, token)
    end
  end

  shared_examples_for "access denied" do
    it "should not allow read" do
      ability.should_not be_able_to(:read, resource, token)
    end
    it "should not allow create" do
      ability.should_not be_able_to(:create, resource, token)
    end
    it "should not allow update" do
      ability.should_not be_able_to(:update, resource, token)
    end
  end

  shared_examples_for "create only" do
    it "should allow create" do
      ability.should be_able_to(:create, resource, token)
    end
    it "should not allow read" do
      ability.should_not be_able_to(:read, resource, token)
    end
    it "should not allow update" do
      ability.should_not be_able_to(:update, resource, token)
    end
  end

  shared_examples_for "read only" do
    it "should not allow create" do
      ability.should_not be_able_to(:create, resource, token)
    end
    it "should allow read" do
      ability.should be_able_to(:read, resource, token)
    end
    it "should not allow update" do
      ability.should_not be_able_to(:update, resource, token)
    end
  end

  context "for general resource" do
    let(:resource) { Object.new }
    context "with admin user" do
      before(:each) { user.stub(:has_role?).and_return(true) }
      it_should_behave_like "access granted"
    end
    context "with customer" do
      it_should_behave_like "access denied"
    end
  end

  context "for User" do
    context "requested by same user" do
      let(:resource) { user }
      it_should_behave_like "access granted"
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
    end
    context "requested by same user (with token)" do
      let(:token) { "foo-token" }
      before(:each) { resource.token = "foo-token" }
      it_should_behave_like "access granted"
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
