require 'spec_helper'
require 'bar_ability.rb'
require 'cancan'

describe Admin::UsersController do
  context "#authorize_admin" do
    let(:user) { User.new }
    let(:mock_user) { mock_model User }
    before do
      controller.stub :current_user => user
      User.stub(:find).with(9).and_return(mock_user)
      User.stub(:new).and_return(mock_user)
    end
    after(:each) { user.roles = [] }
    it "should grant access to users with an admin role" do
      #user.stub :has_role? => true
      user.roles = [Role.find_or_create_by_name('admin')]
      post :index
      response.should render_template :index
    end
    it "should deny access to users with an bar role" do
      user.roles = [Role.find_or_create_by_name('bar')]
      Ability.register_ability(BarAbility)
      post :index
      response.should render_template "shared/unauthorized"
    end
    it "should deny access to users with an bar role" do
      user.roles = [Role.find_or_create_by_name('bar')]
      Ability.register_ability(BarAbility)
      post :update, {:id => 9}
      response.should render_template "shared/unauthorized"
    end
    it "should deny access to users without an admin role" do
      user.stub :has_role? => false
      post :index
      response.should render_template "shared/unauthorized"
    end
  end
end