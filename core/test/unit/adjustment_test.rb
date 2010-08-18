require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

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

    end
  end
end
