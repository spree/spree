require 'spec_helper'
require 'bar_ability'
require 'cancan'

describe Spree::Admin::ShipmentsController do
  context '#authorize_admin' do
    let(:user) { Spree::User.new }
    let(:shipment) { mock_model Spree::Shipment }
    let(:shipping_method) { mock_model Spree::ShippingMethod }
    let(:order) { mock_model(Spree::Order, :number => 'R123', :reload => nil, :save! => true) }

    before do
      controller.stub :current_user => user
      Spree::Shipment.stub(:find).with(9).and_return(shipment)
      Spree::Shipment.stub :find_by_number => shipment
      Spree::Order.stub :find_by_number => order
      Spree::Shipment.stub(:new).and_return(shipment)
      shipment.stub(:order).and_return order
      shipment.stub(:shipping_method).and_return shipping_method
      shipment.stub(:special_instructions=).and_return 'none'
      shipment.stub(:update_attributes).and_return true
      order.stub(:update_attributes).and_return true
      order.stub(:shipments).and_return [shipment]
      order.stub(:shipment).and_return shipment
      order.stub(:shipping_method=).and_return shipping_method
      order.stub(:special_instructions).and_return 'none'
      order.stub(:save).and_return true
      order.stub(:completed?).and_return false
      if Spree::BaseController.spree_responders[:OrdersController].present?
        Spree::BaseController.spree_responders[:OrdersController].clear
      end
    end

    after(:each) { user.roles = [] }

    it 'should grant access to users with an admin role' do
      #user.stub :has_role? => true
      user.roles = [Spree::Role.find_or_create_by_name('admin')]
      post :index
      response.should render_template :index
    end

    it 'should grant access to users with an bar role' do
      user.roles = [Spree::Role.find_or_create_by_name('bar')]
      Spree::Ability.register_ability(BarAbility)
      post :index
      response.should render_template :index
    end

    it 'should grant access to users with an bar role' do
      user.roles = [Spree::Role.find_or_create_by_name('bar')]
      Spree::Ability.register_ability(BarAbility)
      post :edit, { :order_id => 'R123', :id => 9 }
      response.should_not render_template 'shared/unauthorized'
    end

    it 'should grant access to users with an bar role' do
      user.roles = [Spree::Role.find_or_create_by_name('bar')]
      Spree::Ability.register_ability(BarAbility)
      post :update, { :order_id => 'R123', :id => 9 }
      response.should_not render_template 'shared/unauthorized'
    end

    it 'should deny access to users without an admin role' do
      user.stub :has_role? => false
      post :index
      response.should render_template 'shared/unauthorized'
    end
  end
end