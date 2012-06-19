require 'spec_helper'
require 'bar_ability'
require 'cancan'

describe Spree::Admin::ShipmentsController do
  context '#authorize_admin' do
    let(:user) { Spree::User.new }
    let(:shipment) { mock_model Spree::Shipment }
    let(:order) { mock_model(Spree::Order, :special_instructions => [], :completed? => false) }
    let(:shipment) { stub_model(Spree::Shipment, :order => order) }

    before do
      order.stub :shipments => [shipment]
      controller.stub :current_user => user
      controller.stub :order => order
      controller.stub :shipment => shipment
      controller.stub :load_shipping_methods # shut this up
      if Spree::BaseController.spree_responders[:OrdersController].present?
        Spree::BaseController.spree_responders[:OrdersController].clear
      end
    end

    after(:each) { user.roles = [] }

    it 'should grant access to users with an admin role' do
      #user.stub :has_role? => true
      user.roles = [Spree::Role.find_or_create_by_name('admin')]
      spree_get :index
      response.should render_template :index
    end

    it 'should grant access to users with an bar role' do
      user.roles = [Spree::Role.find_or_create_by_name('bar')]
      Spree::Ability.register_ability(BarAbility)
      spree_get :index
      response.should render_template :index
    end

    it 'should grant access to users with an bar role' do
      user.roles = [Spree::Role.find_or_create_by_name('bar')]
      Spree::Ability.register_ability(BarAbility)
      spree_get :edit, { :order_id => 'R123', :id => 9 }
      response.should_not render_template 'shared/unauthorized'
    end

    it 'should grant access to users with an bar role' do
      user.roles = [Spree::Role.find_or_create_by_name('bar')]
      Spree::Ability.register_ability(BarAbility)
      spree_put :update, { :order_id => 'R123', :id => 9 }
      response.should_not render_template 'shared/unauthorized'
    end

    it 'should deny access to users without an admin role' do
      user.stub :has_role? => false
      spree_get :index
      response.should render_template 'shared/unauthorized'
    end
  end
end
