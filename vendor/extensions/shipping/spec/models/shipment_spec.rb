require File.dirname(__FILE__) + '/../spec_helper'

class MockCalculator
end

describe Shipment do
  before :each do
    @order = Order.new
    @shipping_method = ShippingMethod.new(:shipping_calculator => "MockCalculator")
    @shipment = Shipment.new(:order => @order, :shipping_method => @shipping_method)
  end
  
  describe "update" do
    it "should calculate the shipping cost using the specified calculator" do
      MockCalculator.should_receive(:calculate_shipping).with(@order)
      @shipment.save
    end
    it "should assign the calculated cost to the order" do
      MockCalculator.stub!(:calculate_shipping).with(@order).and_return(8.95)
      @order.should_receive(:update_attribute).with(:ship_amount, 8.95)
      @shipment.save
    end
  end
end
