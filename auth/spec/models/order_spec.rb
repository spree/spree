require 'spec_helper'

describe Order do
  let(:order) { Order.new }
  it "#token when user is a guest" do
    user = mock_model(User, :guest? => true, :token => "foo")
    order.user = user
    order.token.should == user.token
  end
  it "#token when user is registered" do
    user = mock_model(User, :guest? => false, :token => "foo")
    order.user = user
    order.token.should be_nil
  end
end