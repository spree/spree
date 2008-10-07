require File.dirname(__FILE__) + '/../spec_helper'

describe ShippingMethod do
  before(:each) do
    @shipping_method = ShippingMethod.new
  end

  describe "available?" do
    it "should be true if the shipping address is located within the method's zone"
    it "should be false if the shipping address is located outside of the method's zone"
  end
  
  describe "calculate_shipping" do
    it "should be 0 if the shipping address does not fall within the method's zone"
    it "should use the calculate_shipping method of the specified calculator if the address matches the method's zone"
  end
end
