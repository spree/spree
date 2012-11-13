require 'spec_helper'

describe Spree::Promotion::Rules::FirstOrder do
  let(:rule) { Spree::Promotion::Rules::FirstOrder.new }
  let(:order) { mock_model(Spree::Order, :user => nil) }

  it "should not be eligible without a user" do
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
  end

  it "should be not eligible if user have at least one complete order" do
    user = mock_model(Spree::LegacyUser)
    user.stub_chain(:orders, :complete, :count => 1)
    order.stub(:user => user)

    rule.should_not be_eligible(order)
  end
end
