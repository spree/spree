require 'spec_helper'

describe UserSessionsController do

  context "#create" do
    context "when current_order is associated with a guest user" do
      let(:user) { mock User }
      let(:order) { mock_model Order }

      before do
        controller.stub :is_devise_resource? => true, :resource_name => nil, :require_no_authentication => nil, :user_signed_in? => true
        controller.stub_chain :warden, :authenticate!
        controller.stub :current_order => order
      end

      it "should associate the order with the newly authenticated user" do
        controller.stub :current_user => user
        order.should_receive(:associate_user!).with user
        post :create, {}, { :order_id => 1 }
      end

      it "should destroy the session token for guest_user" do
        controller.stub :current_user => user
        order.stub :associate_user!
        post :create, {}, { :order_id => 1, :guest_token => "foo" }
        session[:guest_token].should be_nil
      end

    end
  end

end
