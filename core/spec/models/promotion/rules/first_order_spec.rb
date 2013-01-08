require 'spec_helper'

describe Spree::Promotion::Rules::FirstOrder do
  let(:rule) { Spree::Promotion::Rules::FirstOrder.new }
  let(:order) { mock_model(Spree::Order, :user => nil, :email => nil) }

  it "should not be eligible without a user or email" do
    rule.should_not be_eligible(order)
  end

  context "should be eligible if user does not have any other completed orders yet" do
    let(:user) { mock_model(Spree::LegacyUser) }

    before do
      user.stub_chain(:orders, :complete, :count => 0)
    end

    it "for an order without a user, but with user in payload data" do
      rule.should be_eligible(order, :user => user)
    end

    it "for an order with a user, no user in payload data" do
      order.stub :user => user
      rule.should be_eligible(order)
    end

    # Regression test for #2306
    context "for an order with a 'guest' user" do
      let(:email) { 'user@spreecommerce.com' }
      before { order.stub :email => 'user@spreecommerce.com' }

      context "with no other orders" do
        it { rule.should be_eligible(order) }
      end

      context "with another order" do
        before { rule.stub(:orders_by_email => 1) }
        it { rule.should_not be_eligible(order) }
      end
    end

    it "#orders_by_email" do
      Spree::Order.create!(:email => "user@spreecommerce.com")
      rule.orders_by_email("user@spreecommerce.com").should == 1
    end
  end
end
