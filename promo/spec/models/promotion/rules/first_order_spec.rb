require 'spec_helper'

describe Promotion::Rules::FirstOrder do
  let(:rule) { Promotion::Rules::FirstOrder.new }
  let(:order) { mock_model(Order, :user => nil) }

  it "should not be eligible without a user" do
    rule.should_not be_eligible(order)
  end

  it "should be eligible if user does not have any other completed orders yet" do
    user = mock_model(User)
    # TODO: refactor, probably it would be good to change that to method in user model, like completed_orders
    user.stub_chain(:orders, :complete, :count => 0)
    order.stub(:user => user)

    rule.should be_eligible(order)
  end

  it "should be not eligible if user have at least one completet order" do
    user = mock_model(User)
    user.stub_chain(:orders, :complete, :count => 1)
    order.stub(:user => user)

    rule.should_not be_eligible(order)
  end
end
