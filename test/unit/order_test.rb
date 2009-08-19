require 'test_helper'

# TODO: check logic of state machine (mayby separate test case?
# check seslling units / restocking

class OrderTest < ActiveSupport::TestCase
  context "create" do
    setup { Order.create }
    should_change "Checkout.count", :by => 1
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

    should "create default tax charge" do
      assert(@order.tax_charges.first, "Tax charge was not created")
    end    

    context "complete" do
      setup { @order.complete }
      should_change "@order.state", :from => "in_progress", :to => "new"

      should "create shipment" do
        assert(@order.shipments.first, "Shipment was not created")
      end

      should "update checkout completed_at" do
        assert(@order.checkout.completed_at, "Checkout#completed_at was not updated")
      end
    end
  end

end
