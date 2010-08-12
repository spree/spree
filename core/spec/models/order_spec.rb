require 'spec_helper'

describe Order do

  let(:order) { Order.new }

  context "#save" do
    it "should create guest user (when no user assigned)" do
      order.save
      order.user.should_not be_nil
      order.user.should be_guest
    end
    it "should not remove the registered user" do
      order = Order.new
      reg_user = mock_model(User)#User.create(:email => "spree@example.com", :password => 'changeme2', :password_confirmation => 'changeme2')
      order.user = reg_user
      order.save
      order.user.should == reg_user
    end
  end

  context "#register!" do
    it "should change its user to the specified user" do
      order.save
      user = mock_model(User, :guest? => true)
      order.register!(user)
      order.user.should == user
    end
    it "should fail if it already has a registered user" do
      user = mock_model(User, :guest? => false)
      order.save
      expect {
        order.register!(user)
      }.to raise_error
    end
    #TODO think about expected behavior for guest credit cards when changing to registered user, etc.
  end

  context "#next!" do
    it "should complete order when state is complete" do
      order.state = "confirm"
      order.next!
      order.complete?.should be_true
    end
  end

  it "should indicate whether its user is a guest" do
    order.user = mock_model(User, :guest? => true)
    order.should be_guest
    order.user = mock_model(User, :guest? => false)
    order.should_not be_guest
  end

  it "should indicate if order is complete" do
    order.completed_at = nil
    order.complete?.should be_false

    order.completed_at = Time.now
    order.complete?.should be_true
  end

end