require 'spec_helper'

describe Order do
  let(:order) { Order.new }
  context "#token" do
    it "should be the same as the user's token when the user is a guest" do
      user = mock_model(User, :guest? => true, :token => "foo")
      order.user = user
      order.token.should == user.token
    end
    it "should be nil when the user is registered" do
      user = mock_model(User, :guest? => false, :token => "foo")
      order.user = user
      order.token.should be_nil
    end
  end
end