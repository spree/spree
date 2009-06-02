require 'test_helper'

class OrdersControllerTest < ActionController::TestCase
  fixtures :countries, :states, :gateways, :gateway_configurations
  
  context "on POST to :checkout" do
    setup do
      @order_attributes = {:bill_address_attributes => Factory.build(:address).attributes.symbolize_keys, 
                           :ship_address_attributes => Factory.build(:address).attributes.symbolize_keys} 
    end
    context "with no existing address" do
      setup do
        session[:order_id] = Factory.create(:order, :bill_address => nil, :ship_address => nil).id
        post :checkout, :order => @order_attributes
      end
      should_change "Address.count", :by => 2
    end
    context "with existing address" do
      setup do
        session[:order_id] = Factory.create(:order).id
        post :checkout, :order => @order_attributes
      end
      should_change "Address.count", :by => 2
    end
  end
end