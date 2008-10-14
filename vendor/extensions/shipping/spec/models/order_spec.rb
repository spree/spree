require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Order do
  before(:each) do
    @order = Order.new(:address => @address = mock_model(Address, :null_object => true))
    #add_stubs(@order, :save => true)
  end

  describe "shipping_countries" do
    it "should return an empty array if there are no shipping methods configured" do
      ShippingMethod.stub!(:all).and_return([])
      @order.shipping_countries.should == []
    end
    it "should contain only a single country even if multiple shipping methods are configured with that same country" do
      country = mock_model(Country)
      method1 = mock_model(ShippingMethod, :zone => mock_model(Zone, :country_list => [country]))
      method2 = mock_model(ShippingMethod, :zone => mock_model(Zone, :country_list => [country]))
      ShippingMethod.stub!(:all).and_return([method1, method2])
      @order.shipping_countries.should == [country]
    end
    it "should contain the unique list of countries that fall within at least one shipping method's zone" do
      country1 = mock_model(Country)
      country2 = mock_model(Country)
      method1 = mock_model(ShippingMethod, :zone => mock_model(Zone, :country_list => [country1]))
      method2 = mock_model(ShippingMethod, :zone => mock_model(Zone, :country_list => [country2]))
      ShippingMethod.stub!(:all).and_return([method1, method2])
      @order.shipping_countries.should == [country1, country2]
    end
  end
  
  describe "shipping_methods" do
    it "should return empty array if there are no shipping methods configured" do
      ShippingMethod.stub!(:all).and_return([])
      @order.shipping_methods.should == []
    end
    it "should check the shipping address against the shipping method's zone" do
      zone = mock_model(Zone)
      method = mock_model(ShippingMethod, :zone => zone)
      ShippingMethod.stub!(:all).and_return([method])
      zone.should_receive(:include?).with(@address)
      @order.shipping_methods
    end
    it "should return empty array if none of the configured shipping methods cover the shipping address" do
      method = mock_model(ShippingMethod, :zone => mock_model(Zone, :include? => false))
      ShippingMethod.stub!(:all).and_return([method])
      @order.shipping_methods.should == []
    end
    it "should return all shipping methiods that cover the shipping address" do
      method1 = mock_model(ShippingMethod, :zone => mock_model(Zone, :include? => true))
      method2 = mock_model(ShippingMethod, :zone => mock_model(Zone, :include? => true))
      method3 = mock_model(ShippingMethod, :zone => mock_model(Zone, :include? => false))
      ShippingMethod.stub!(:all).and_return([method1, method2, method3])
      @order.shipping_methods.should == [method1, method2]
    end
  end
end