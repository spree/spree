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
    
    context "manifest" do
      setup do
        create_complete_order
          
        @order.line_items.clear
        @variant1 = Factory(:variant)
        @variant2 = Factory(:variant)
        Factory(:line_item, :variant => @variant1, :order => @order, :quantity => 2)
        Factory(:line_item, :variant => @variant2, :order => @order, :quantity => 3)
        @order.reload

        @shipment = @order.shipment        
        @order.complete
      end
      
      should "match the inventory units assigned" do
        assert 2, @shipment.manifest.length
        assert @shipment.manifest.map(&:variant).include?(@variant1)
        assert @shipment.manifest.map(&:variant).include?(@variant2)
        assert_equal 2, @shipment.manifest.detect{|i| i.variant == @variant1}.quantity
        assert_equal 3, @shipment.manifest.detect{|i| i.variant == @variant2}.quantity
      end
      
    end
    
    context "line_items" do
      setup do
        create_complete_order
        @order.line_items.clear
        @line_item1 = Factory(:line_item, :variant => Factory(:variant), :order => @order, :quantity => 2)
        @line_item2 = Factory(:line_item, :variant => Factory(:variant), :order => @order, :quantity => 3)
        @line_item3 = Factory(:line_item, :variant => Factory(:variant), :order => @order, :quantity => 4)
        @order.reload
        @order.complete
        @shipment = @order.shipment
      end
      should "be the same as @order.line_items when there is only one shipment" do
        assert_equal 3, @order.shipment.line_items.length
      end
      should "include only line items for each shipment when the order has multiple shipments" do
        @new_shipment = @order.shipments.create(:shipping_method => @shipment.shipping_method, :address => @shipment.address)
        
        # move all inventory units for @line_item3 to the new shipment
        inventory_units_to_move = @shipment.inventory_units.select{|iu| iu.variant == @line_item3.variant}
        inventory_units_to_move.each {|iu| iu.update_attribute(:shipment, @new_shipment) }
        @shipment.reload
        
        assert_equal 2, @shipment.line_items.length
        assert @shipment.line_items.include?(@line_item1)
        assert @shipment.line_items.include?(@line_item2)
        
        assert_equal 1, @new_shipment.line_items.length
        assert @new_shipment.line_items.include?(@line_item3)
      end
    end
    
  end

end
