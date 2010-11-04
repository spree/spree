require 'spec_helper'

describe UserSessionsController do
  before(:each) do
  end

  context "#create" do
    context "when current_order is associated with a guest user" do
      let(:user) { mock_model User }
      let(:order) { mock_model Order, :user => user }

      before do
        controller.stub :authorize!
        controller.stub :current_order => order
      end

      it "should associate the order with the newly authenticated user" do
        registered_user = mock_model User
        controller.stub :current_user => registered_user
        order.should_receive(:associate_user!).with registered_user
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
