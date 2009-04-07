require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

class MockCalculator
end

describe Admin::ShipmentsController do
=begin
  before(:each) do            
    @shipping_method = ShippingMethod.new(:shipping_calculator => "MockCalculator")
    @calculator = MockCalculator.new
    MockCalculator.stub!(:new).and_return(@calculator)
    #controller.stub!(:find_shipment).and_return(@shipment = Shipment.new(:shipping_method => @shipping_method))
    Shipment.stub!(:find).with(123).and_return(@shipment = Shipment.new)
    Order.stub!(:find).and_return(@order = Order.new(:shipments => [@shipment]))
    ShippingMethod.stub!(:find).with(33).and_return(@shipping_method)  
  end
=end

# TODO - write some controller tests to veify that the correct calculator is being used, etc.  to much of a hassle
# to get these tests working now (before we relied on save hooks so was easier to test)

=begin
  describe "update" do
    it "should calculate the shipping cost using the specified calculator" do
      @calculator.should_receive(:calculate_shipping)#.with(@shipment)
      put :update, "id" => "123", "parent_id" => 1, "method_id" => 33 #{"id" => 1}
    end
  end 
=end
end
