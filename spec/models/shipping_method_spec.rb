require File.dirname(__FILE__) + '/../spec_helper'

class MockCalculator           
  def available?(shipment)
    true
  end
  def calculate_shipping(shipment)
    2.5
  end
end

class MockUnavailableCalculator           
  def available?(shipment)
    false
  end
end

describe ShippingMethod do
  before(:each) do
    @calculator = MockCalculator.new
    MockCalculator.stub!(:new, :return => @calculator)
    @zone = mock_model(Zone)
    @address = mock_model(Address)
    @shipping_method = ShippingMethod.new(:zone => @zone, :shipping_calculator => "MockCalculator")
    @shipment = mock_model(Shipment, :address => @address)
  end

  describe "available?" do      
    it "should return true if the calculator indicates method is supported" do
      @shipping_method.available?(@shipment).should be_true
    end
    it "should return false if the calculator indicates method is not supported"  do
      @shipping_method = ShippingMethod.new(:zone => @zone, :shipping_calculator => "MockUnavailableCalculator")
      @shipping_method.available?(@shipment).should be_false
    end
  end
  
  describe "calculate_shipping" do
    it "should be 0 if the shipping address does not fall within the method's zone" do
      @zone.stub!(:include?).with(@address).and_return(false)
      @shipping_method.calculate_shipping(@shipment).should == 0
    end
    describe "when the shipping address is included within the method's zone" do
      before :each do
        @zone.stub!(:include?).with(@address).and_return(true)
        # TODO - stub out instatiation code        
      end
      it "should use the calculate_shipping method of the specified calculator" do
        @calculator = MockCalculator.new
        MockCalculator.stub!(:new, :return => @calculator)
        @calculator.should_receive(:calculate_shipping).with(@shipment)
        @shipping_method.calculate_shipping(@shipment)
      end
      it "should return the correct amount" do
        @shipping_method.calculate_shipping(@shipment).should == 2.5
      end
    end
  end
end
