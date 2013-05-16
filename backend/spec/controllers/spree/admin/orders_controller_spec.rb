require 'spec_helper'
require 'cancan'
require 'spree/testing_support/bar_ability'

# Ability to test access to specific model instances
class OrderSpecificAbility
  include CanCan::Ability

  def initialize(user)
    can [:admin, :manage], Spree::Order, :number => 'R987654321'
  end
end

describe Spree::Admin::OrdersController do

  before { Spree::Order.stub :find_by_number! => order }

  context "without auth" do
    stub_authorization!

    before do
      request.env["HTTP_REFERER"] = "http://localhost:3000"

      # ensure no respond_overrides are in effect
      if Spree::BaseController.spree_responders[:OrdersController].present?
        Spree::BaseController.spree_responders[:OrdersController].clear
      end
    end

    let(:order) { mock_model(Spree::Order, :complete? => true, :total => 100, :number => 'R123456789') }

    context "#fire" do
      it "should fire the requested event on the payment" do
        order.should_receive(:foo).and_return true
        spree_put :fire, {:id => "R1234567", :e => "foo"}
      end

      it "should respond with a flash message if the event cannot be fired" do
        order.stub :foo => false
        spree_put :fire, {:id => "R1234567", :e => "foo"}
        flash[:error].should_not be_nil
      end
    end

    context "pagination" do
      it "can page through the orders" do
        spree_get :index, :page => 2, :per_page => 10
        assigns[:orders].offset_value.should == 10
        assigns[:orders].limit_value.should == 10
      end
    end
  end

  context '#authorize_admin' do
    let(:user) { create(:user) }
    let(:order) { create(:completed_order_with_totals, :number => 'R987654321') }

    before do
      controller.stub :spree_current_user => user
    end

    it 'should grant access to users with an admin role' do
      user.spree_roles << Spree::Role.find_or_create_by_name('admin')
      spree_post :index
      response.should render_template :index
    end

    it 'should grant access to users with an bar role' do
      user.spree_roles << Spree::Role.find_or_create_by_name('bar')
      Spree::Ability.register_ability(BarAbility)
      spree_post :index
      response.should render_template :index
      Spree::Ability.remove_ability(BarAbility)
    end

    it 'should deny access to users with an bar role' do
      order.stub(:update_attributes).and_return true
      order.stub(:user).and_return Spree.user_class.new
      order.stub(:token).and_return nil
      user.spree_roles.clear
      user.spree_roles << Spree::Role.find_or_create_by_name('bar')
      Spree::Ability.register_ability(BarAbility)
      spree_put :update, { :id => 'R123' }
      response.should redirect_to('/unauthorized')
      Spree::Ability.remove_ability(BarAbility)
    end

    it 'should deny access to users without an admin role' do
      user.stub :has_spree_role? => false
      spree_post :index
      response.should redirect_to('/unauthorized')
    end

    it 'should restrict returned order(s) on index when using OrderSpecificAbility' do
      number = order.number

      3.times { create(:completed_order_with_totals) }
      Spree::Order.complete.count.should eq 4
      Spree::Ability.register_ability(OrderSpecificAbility)

      user.stub :has_spree_role? => false
      spree_get :index
      response.should render_template :index
      assigns['orders'].size.should eq 1
      assigns['orders'].first.number.should eq number
      Spree::Order.accessible_by(Spree::Ability.new(user), :index).pluck(:number).should eq  [number]
    end
  end
end
