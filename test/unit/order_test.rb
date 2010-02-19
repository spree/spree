require 'test_helper'

# TODO: check logic of state machine (mayby separate test case?
# check seslling units / restocking

class OrderTest < ActiveSupport::TestCase
  context "create" do
    setup { Order.create }
    should_change("Checkout.count", :by => 1) { Checkout.count }
  end
  
  context "Order" do
    setup { create_complete_order }
  
    should "have line_items" do
      assert @order.line_items.length > 0
    end
  
    should "have token generated" do
      assert(@order.token, "Token was not generated")
    end
  
    should "remove line items if quantity drops to 0" do
      @order.save   # wipe any accidental zeros
      l = @order.line_items.length
      @order.line_items.first.update_attribute(:quantity, 0)
      @order.save
      assert_equal(l-1, @order.line_items.length)
    end
  
    should "update totals" do
      @order.item_total = nil
      @order.adjustment_total = nil
      @order.total = nil
      @order.update_totals
      assert_not_nil(@order.item_total)
      assert_not_nil(@order.charge_total)
      assert_not_nil(@order.total)
    end
  
    context "when line_items change" do
      setup do 
        @first_price = @order.line_items.first.price
        @order.line_items.first.update_attribute(:quantity, @order.line_items.first.quantity + 1)
        @order.save
      end
      should_change("item total", :by => @first_price) { @order.item_total }
    end
  
    should "create default tax charge" do
      assert(@order.tax_charges.first, "Tax charge was not created")
    end
  
    context "complete" do
      setup { @order.complete }
      should_change("@order.state", :from => "in_progress", :to => "new") { @order.state }
  
      should "create shipment" do
        assert(@order.shipments.first, "Shipment was not created")
        assert_equal 'pending', @order.shipments.first.state
      end
  
      should "update checkout completed_at" do
        assert(@order.checkout.completed_at, "Checkout#completed_at was not updated")
      end
      
      should "create inventory units" do
        total_quantity = @order.line_items.map(&:quantity).sum
        assert_equal total_quantity, @order.inventory_units.count
        assert_equal total_quantity, @order.shipment.inventory_units.count
      end
      
      context "with empty stock" do
        setup do
          line_item = @order.line_items.first
          num_left = line_item.variant.inventory_units.with_state("on_hand").count
          InventoryUnit.destroy_on_hand(line_item.variant, num_left)
        end
        should "be able to save order when allow_backorders is off" do
          Spree::Config.set(:allow_backorders => false)
          assert(@order.save == true, "Completed order could not be saved")
          Spree::Config.set(:allow_backorders => true)
        end
      end
    end
    
    context "pay!" do
      should "make all shipments ready" do
        @order.complete!
        @order.pay!
        assert @order.shipments.all?(&:ready_to_ship?), "shipments didn't all have state ready_to_ship"
      end
    end
  
    context "ship!" do
      should "make all shipments shipped" do
        @order.update_attribute(:state, 'paid')
        @order.ship!
        assert @order.shipments.all?(&:shipped?), "shipments didn't all have state shipped"
      end
    end
  
    context "under_paid!" do
      should "make all shipments pending" do
        @order.complete!
        @order.pay!
        @order.under_paid!
        assert @order.shipments.all?(&:pending?), "shipments didn't all have state pending"
      end
    end
    
  end

  context "outstanding_balance and outstanding_credit" do
    setup do
      @order = Factory(:order)
      Factory(:line_item, :variant => Factory(:variant, :price => 5.00), :order => @order, :quantity => 1, :price => 5.00)
      @order.reload
      @order.save
      Factory(:payment, :payable => @order, :amount => 2.50)
      @order.reload
      @order.save
    end
    
    context "with outstanding balance of 2.50" do
      should "be have outstanding_balance of 2.50" do
        assert_equal 2.50, @order.outstanding_balance.to_f
      end
      should "be have outstanding_credit of 0.00" do
        assert_equal 0.00, @order.outstanding_credit.to_f
      end
    end

    context "with outstanding credit of 2.50" do
      setup do
        @order.payments.first.update_attribute(:amount, 8.00)
      end
      should "be have outstanding_balance of 0.00" do
        assert_equal 0.00, @order.outstanding_balance.to_f
      end
      should "be have outstanding_credit of 2.50" do
        assert_equal 3.00, @order.outstanding_credit.to_f
      end
    end

    context "with no outstanding balance or credit" do
      setup do
        @order.payments.first.update_attribute(:amount, 5.00)
      end
      should "be have outstanding_balance of 0.00" do
        assert_equal 0.00, @order.outstanding_balance.to_f
      end
      should "be have outstanding_credit of 0.00" do
        assert_equal 0.00, @order.outstanding_credit.to_f
      end
    end

  end

end
