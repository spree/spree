require 'spec_helper'
require 'bar_ability'
require 'cancan'

describe Spree::Admin::OrdersController do

  let(:order) { mock_model(Spree::Order, :number => 'R123', :reload => nil, :save! => true) }
  before do
    Spree::Order.stub :find_by_number => order
    #ensure no respond_overrides are in effect
    if Spree::BaseController.spree_responders[:OrdersController].present?
      Spree::BaseController.spree_responders[:OrdersController].clear
    end
  end

  context '#authorize_admin' do
    let(:user) { Spree::User.new }

    before do
      controller.stub :current_user => user
      Spree::Order.stub(:new).and_return(order)
    end

    after(:each) { user.roles = [] }

    it 'should grant access to users with an admin role' do
      #user.stub :has_role? => true
      user.roles = [Spree::Role.find_or_create_by_name('admin')]
      spree_post :index
      response.should render_template :index
    end

    it 'should grant access to users with an bar role' do
      user.roles = [Spree::Role.find_or_create_by_name('bar')]
      Spree::Ability.register_ability(BarAbility)
      spree_post :index
      response.should render_template :index
    end

    it 'should deny access to users with an bar role' do
      order.stub(:update_attributes).and_return true
      order.stub(:user).and_return Spree::User.new
      order.stub(:token).and_return nil
      user.roles = [Spree::Role.find_or_create_by_name('bar')]
      Spree::Ability.register_ability(BarAbility)
      spree_post :update, { :id => 'R123' }
      response.should render_template 'spree/shared/unauthorized'
    end

    it 'should deny access to users without an admin role' do
      user.stub :has_role? => false
      spree_post :index
      response.should render_template 'spree/shared/unauthorized'
    end
  end
end
