require 'spec_helper'

describe OrdersController do
  context "#populate" do
    before { Order.stub(:create).and_return mock_model(Order, :token => "foo") }
    it "should store a guest token (for new guest order)" do
      controller.should_receive(:current_user).and_return(nil)
      post :populate, {}, {}
      session[:guest_token].should_not be_nil
    end
    it "should not store a guest token (for new registered user order)" do
      controller.should_receive(:current_user).and_return mock_model(User)
      post :populate, {}, {}
      session[:guest_token].should be_nil
    end
  end

end