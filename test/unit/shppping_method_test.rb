require 'test_helper'

class ShippingMethodTest < ActiveSupport::TestCase
  context "instance" do
    setup do 
      @calculator = Factory(:calculator)
      @shipping_method = Factory(:shipping_method, :calculator => @calculator)  
      @zone = @shipping_method.zone                 
      @shipment = Factory(:shipment)
      @order = @shipment.order           
    end
    context "when calculator indicates method is supported" do
      setup { @calculator.stub!(:available?, :return => true) }
      should "be available" do
        assert @shipping_method.available?(@order)
      end
      context "when the shipping address does not fall within the method's zone" do
        setup { @zone.stub!(:include?, :return => false) } 
        should "return 0 when calculating shipping for that method" do
          assert_equal 0, @shipping_method.calculate_shipping(@shipment)
        end      
      end
      context "when the shipping address falls within the method's zone" do
        setup { @zone.stub!(:include?, :return => true) }
        should "return the amount as calculated by the method's calculator" do
          assert_equal 5, @shipping_method.calculate_shipping(@shipment)
        end      
      end
    end
    context "when calculator indicates method is not supported" do
      setup { @calculator.stub!(:available?, :return => false) }
      should "not be available" do
        assert !@shipping_method.available?(@order)
      end
    end
  end                 
end