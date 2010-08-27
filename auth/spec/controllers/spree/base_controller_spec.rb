require 'spec_helper'

describe Spree::BaseController do

  context "#auth_user" do
    let(:user) { mock_model User }

    context "when authenticated" do
      before { controller.stub :current_user => user }

      it "should return the authenticated user" do
        controller.auth_user.should == user
      end

    end

    context "when unauthenticated" do
      before { controller.stub :current_user => nil }

      it "should return nil if there is no guest_token" do
        User.stub :find_by_access_token => nil
        session[:guest_user] = nil
        controller.auth_user.should be_nil
      end

      it "should return the user matching the token" do
        User.stub :find_by_authentication_token => user
        session[:guest_user] = "foo"
        controller.auth_user.should == user
      end

      it "should return nil if there is no database record associated with the guest_token" do
        User.stub :find_by_access_token => nil
        session[:guest_user] = "foo"
        controller.auth_user.should be_nil
      end
    end
  end

end