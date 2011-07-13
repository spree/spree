require 'spec_helper'
require 'bar_ability.rb'
require 'cancan'

describe Admin::OrdersController do
  
  let(:order) { mock_model(Order, :number => "R123", :reload => nil, :save! => true, :coupon_code= => nil, :coupon_code => nil) }
  before do
    Order.stub :find_by_number => order
    #ensure no respond_overrides are in effect
    if Spree::BaseController.spree_responders[:OrdersController].present?
      Spree::BaseController.spree_responders[:OrdersController].clear
    end
  end

  context "#authorize_admin" do
    let(:user) { User.new }
    before do
      controller.stub :current_user => user
      Order.stub(:new).and_return(order)
    end
    after(:each) { user.roles = [] }
    it "should grant access to users with an admin role" do
      #user.stub :has_role? => true
      user.roles = [Role.find_or_create_by_name('admin')]
      post :index
      response.should render_template :index
    end
    it "should grant access to users with an bar role" do
      user.roles = [Role.find_or_create_by_name('bar')]
      Ability.register_ability(BarAbility)
      post :index
      response.should render_template :index
    end
    it "should deny access to users with an bar role" do
      order.stub(:update_attributes).and_return true
      order.stub(:user).and_return User.new
      order.stub(:token).and_return nil
      user.roles = [Role.find_or_create_by_name('bar')]
      Ability.register_ability(BarAbility)
      post :update, {:id => 'R123'}
      response.should render_template "shared/unauthorized"
    end
    it "should deny access to users without an admin role" do
      user.stub :has_role? => false
      post :index
      response.should render_template "shared/unauthorized"
    end
  end
end