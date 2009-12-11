require 'test_helper'

class ShippingMethodTest < ActiveSupport::TestCase
  context "instance" do
    setup do 
      create_complete_order
    end
    context "when calculator indicates method is supported" do
      should "be available" do
        assert(@zone.include?(@order.shipment.address), "Zone doesn't include address")
        assert(@shipping_method.calculator)
        assert @shipping_method.available_to_address?(@order.shipment.address)
      end
      context "when the shipping address falls within the method's zone" do
        should "return the amount as calculated by the method's calculator" do
          assert_equal BigDecimal.new("10.0"), @shipping_method.calculate_cost(@order.shipment)
        end      
      end
    end
  end                 
end