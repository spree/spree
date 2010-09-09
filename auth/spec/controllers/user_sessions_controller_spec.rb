require 'spec_helper'

describe UserSessionsController do
  before(:each) do
  end

  context "#create" do
    context "when current_order is associated with a guest user" do
      let(:user) { mock_model User, :has_role? => false }
      let(:order) { mock_model Order, :anonynmous? => true, :user => user }

      before do
        controller.stub :authorize! => true
        controller.stub :current_order => order
        controller.stub :current_user => user
      end

      it "should associate the order with the newly authenticated user" do
        controller.stub :authorize! => true
        controller.stub_chain :warden, :authenticated? => true
        controller.stub :current_order => order

        order.should_receive(:associate_user!).with user
        post :create, {}, { :order_id => 1 }
      end

      it "should destroy the session token for guest_user" do
        order.stub :associate_user!
        post :create, {}, { :order_id => 1, :guest_token => "foo" }
        session[:guest_token].should be_nil
      end

    end
  end

end
