require 'test_helper'

class TestAdjustment < Adjustment
  attr_accessor :applicable
  attr_accessor :adjustment_amount

  # true by default ;) I love tri-state logic
  def applicable?
    @applicable.nil? ? true : @applicable
  end

  def calculate_adjustment
    @adjustment_amount || 10
  end
end

class AdjustmentTest < ActiveSupport::TestCase
  should_validate_presence_of :description

  context "Adjustment with order" do
    setup do
      create_complete_order
      TestAdjustment.create(:order => @order, :description => "TestAdjustment")
      @adjustment = @order.reload.adjustments.select{|a| a.class==TestAdjustment}.first
    end

    context "with non integer amount" do
      setup {@adjustment = @order.adjustments.create(:amount => 19.95, :description => "Test Charge")}
      should "create adjument with the correct amount" do
        assert_equal 19.95, @adjustment.amount
      end
    end

    context "not completed" do
      setup do
        @order.completed_at = nil
        assert(!@order.checkout_complete, 'Order was completed, adjustments are freezed')
      end

      should "find all types of charges" do
        Charge.create(:order => @order, :description => "TestCharge")
        ShippingCharge.create(:order => @order, :description => "TestCharge")
        TestAdjustment.create(:order => @order, :description => "TestCharge")
        assert_equal(4, @order.reload.charges.length) # 3 + default tax charge
      end

      should "find all types of adjustments" do
        Charge.create(:order => @order, :description => "TestCharge")
        ShippingCharge.create(:order => @order, :description => "TestCharge")
        Adjustment.create(:order => @order, :description => "TestAdjustment")
        assert_equal(6, @order.reload.adjustments.length) # default shipping charge, default tax charge, test adjustment + 3
      end

      should "remove adjustments if they are no longet applicable" do
        @adjustment.applicable = false
        @order.update_totals
        assert_equal(["ShippingCharge", "TaxCharge"], @order.adjustments.map{|a| a.type}.sort)
        assert_equal 2, @order.adjustments.length # tax charge nad shipping charge should still be there
        assert_nil Adjustment.find_by_id(@adjustment.id)
      end

      should "not remove adjustments if they are applicable" do
        @adjustment.applicable = true
        @order.update_totals
        assert_equal 3, @order.adjustments.length
        assert Adjustment.find_by_id(@adjustment.id)
      end
    end
    
    context "with checkout finished" do
      setup do
         @order.completed_at = Time.now
         @order.complete!
      end

      should "save amounts of all adjustments" do
        assert @order.adjustments.reload.all{|a| a.read_attribute(:amount)}
      end

      should "not change amounts" do
        @adjustment.adjustment_amount = 20
        @order.update_totals
        assert_equal 10, @order.adjustments.select{|a| a.class==TestAdjustment}.first.amount
      end

      should "not remove adjustments if they are no longet applicable" do
        @adjustment.applicable = false
        @order.update_totals
        assert_equal(["ShippingCharge", "TaxCharge", "TestAdjustment"], @order.adjustments.map{|a| a.type}.sort)
        assert_equal 3, @order.adjustments.length # tax charge nad shipping charge should still be there
      end
    end
  end
end
