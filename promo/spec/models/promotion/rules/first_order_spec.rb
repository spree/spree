require 'spec_helper'

describe Spree::Promotion::Rules::FirstOrder do
  let(:rule) { Spree::Promotion::Rules::FirstOrder.new }
  let(:order) { mock_model(Spree::Order, :user => nil) }

  it "should not be eligible without a user" do
    rule.should_not be_eligible(order)
  end

  it "should be eligible if user does not have any other completed orders yet" do
    user = mock_model(Spree::User)
    # TODO: refactor, probably it would be good to change that to method in user model, like completed_orders
    user.stub_chain(:orders, :complete, :count => 0)

    rule.should be_eligible(order, :user => user)
  end

  it "should be not eligible if user have at least one complete order" do
    user = mock_model(Spree::User)
    user.stub_chain(:orders, :complete, :count => 1)
    order.stub(:user => user)

    rule.should_not be_eligible(order)
  end
end
