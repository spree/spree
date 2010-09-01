require 'spec_helper'
require 'cancan'

describe Admin::OrdersController do
  context "#authorize_admin" do
    let(:user) { mock_model User }
    before { controller.stub :current_user => user }
    it "should grant access to users with an admin role" do
      user.stub :has_role? => true
      post :index
      response.should render_template :index
    end
    it "should deny access to users without an admin role" do
      user.stub :has_role? => false
      post :index
      response.should render_template "shared/unauthorized"
    end
  end
end