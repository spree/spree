require 'test_helper'
class ShipmentTest < ActiveSupport::TestCase

  context "State machine" do
    setup { @shipment = Factory(:shipment) }

    should "be pending initially" do
      assert Shipment.new.pending?
    end
    
    should "change to ready_to_ship when completed" do
      @shipment.ready!
      assert @shipment.ready_to_ship?
    end

    should "log events" do
      assert @shipment.state_events.empty?
      @shipment.ready!
      assert_equal 1, @shipment.state_events.count
      assert_equal 'pending', @shipment.state_events.first.previous_state
    end

    context "when shipped" do    
      setup do
        @order = Factory(:order, :state => 'paid')
        @shipment = @order.shipment
        @shipment.update_attribute(:state, 'acknowledged')
      end
      
      should "make order shipped when this is the only shipment" do
        @shipment.ship!
        @order.reload
        assert @order.shipped?
      end
      should "not make order shipped if order has another unshipped shipment" do
        Factory(:shipment, :order => @order)

        @shipment.ship!
        @order.reload
        assert !@order.shipped?
      end
      
      should "set shipped_at" do
        @shipment.ship!
        assert @shipment.shipped_at
      end
    end
  end

end
