require 'spec_helper'

describe OrdersController do
  context "#populate" do
    pending "should store a guest token (for new guest order)" do
      post :populate, {}, {}
      session[:guest_token].should == order.token
    end
    it "should not store a guest token (for new registered user order)"
  end
end