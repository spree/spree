require 'spec_helper'

describe Order do
  let(:order) { Order.new }
  context "#token" do
    it "should be the same as the user's token when the user is a guest" do
      user = mock_model(User, :anonymous? => true, :token => "foo")
      order.user = user
      order.token.should == user.token
    end
    it "should be nil when the user is registered" do
      user = mock_model(User, :anonymous? => false, :token => "foo")
      order.user = user
      order.token.should be_nil
    end
  end
  context "#associate_user!" do
    let(:user) { mock_model User, :anonymous? => false }
    before { order.stub(:save! => true) }

    it "should associate the order with the specified user" do
      order.associate_user! user
      order.user.should == user
    end

    it "should destroy any previous association with a guest user" do
      guest_user = mock_model User
      order.user = guest_user
      order.associate_user! user
      order.user.should_not == guest_user
    end

    it "should change the guest flag to false" do
      order.associate_user! user
      order.anonymous?.should be_false
    end
  end
end