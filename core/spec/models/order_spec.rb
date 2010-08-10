require 'spec_helper'

describe Order do
  context "#create" do
    it "should create associated guest user" do
      order = Order.create
      order.user.should_not be_nil
      order.user.guest?.should be_true
    end
  end
end