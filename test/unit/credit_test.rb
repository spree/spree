require 'test_helper'

class CreditTest < ActiveSupport::TestCase
  should_validate_presence_of :amount     
  should_validate_numericality_of :amount
  should_validate_presence_of :description
  context "order instance with discounts" do
    setup do
      @order = Factory(:order)
      @credit = Factory(:credit, :amount => 2.00, :order => @order)
      @order.save
    end

    should "set positive credit_total" do
      assert_equal("2.0", @order.credit_total.to_s)
    end

    should "not set negative charge_total" do
      assert_equal("0.0", @order.charge_total.to_s)
    end

    should "set negative adjustment_total" do
      assert_equal("-2.0", @order.adjustment_total.to_s)
    end

    should "decrase total" do
      assert_equal(@order.item_total - 2.00, @order.total)
    end

    context "when adding another discount" do
      setup do
        Factory(:credit, :amount => 1.00, :order => @order)
        @order.save
      end
      
      should_change "@order.total", :by => BigDecimal("-1.00")
      should_change "@order.credit_total", :by => BigDecimal("1.00")
      should_not_change "@order.item_total"
    end
    
    context "when destroying a credit" do
      setup do 
        @order.credits.destroy_all
        @order.save
      end
      should_change "@order.total", :by => BigDecimal("2.00")
      should_change "@order.credit_total", :by => BigDecimal("-2.00")
      should_not_change "@order.item_total"
    end
  end  
end
