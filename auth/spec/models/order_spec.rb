require 'spec_helper'

describe Order do
  let(:order) { Order.new }
  context "#token" do
    it "should be the same as the user's token" do
      user = mock_model(User, :token => "foo")
      order.user = user
      order.token.should == user.token
    end
  end
  context "#associate_user!" do
    let(:user) { mock_model User, :email => 'spree@example.com' }
    before { order.stub(:save! => true) }

    it "should associate the order with the specified user" do
      order.associate_user! user
      order.user.should == user
    end

    it "should set the order's email attribute to that of the specified user" do
      order.associate_user! user
      order.email.should == user.email
    end

    it "should destroy any previous association with a guest user" do
      guest_user = mock_model User
      order.user = guest_user
      order.associate_user! user
      order.user.should_not == guest_user
    end

  end

  context "with bogus email" do
    it "should not be valid" do
      order.stub(:new_record? => false)
      order.email = "foo"
      order.state = 'address'
      order.should_not be_valid
    end
  end
end
