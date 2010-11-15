require 'spec_helper'

describe Spree::BaseController do
  def mock_user(stubs={})
    @mock_user ||= mock_model(User, stubs).as_null_object
  end

  context "#auth_user" do
    let(:user) { mock_user }

    context "when authenticated" do
      before { controller.stub :current_user => mock_user }

      it "should return the authenticated user" do
        User.stub(:find_by_persistence_token).with(nil).and_return mock_model(User)
        controller.auth_user.should == user
      end

      it "should return the authenticated user (even if guest_token present)" do
        session[:guest_token] = "foo"
        User.stub :find_by_persistence_token => mock_user
        controller.auth_user.should == user
      end

    end

    context "when unauthenticated" do
      before { controller.stub :current_user => nil }

      it "should return nil if there is no guest_token" do
        User.stub :find_by_access_token => nil
        session[:guest_token] = nil
        controller.auth_user.should be_nil
      end

      it "should return the user matching the token" do
        User.stub :find_by_persistence_token => user
        session[:guest_token] = "foo"
        controller.auth_user.should == user
      end

      it "should return nil if there is no database record associated with the guest_token" do
        User.stub :find_by_access_token => nil
        session[:guest_token] = "foo"
        controller.auth_user.should be_nil
      end
    end
  end

end
