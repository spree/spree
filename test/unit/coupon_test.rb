require 'test_helper'

class CouponTest < ActiveSupport::TestCase
  should_validate_presence_of :code
  
  context "instance" do
    setup do
      @checkout = Factory(:checkout)
      @coupon = Factory(:coupon)
    end
#    context "create_discount" do
#      setup do
#        TestCouponCalc.stub!(:test_amount, :return => 0.99 )
#        @checkout.order.stub!(:item_total, :return => 15)
#        @discount = @coupon.create_discount(@checkout)
#      end
#      should_change "@checkout.discounts.count", :by => 1
#      should "create a discount with an amount determined by the calculator" do
#        assert_equal BigDecimal.new("0.99"), @discount.amount
#      end
#      should_change "@checkout.order.credits.count", :by => 1
#      should "create a credit with the amount determined by the calculator" do
#        assert_equal BigDecimal.new("0.99"), @discount.credit.amount
#      end
#      context "with additional coupon" do
#        setup { @additional_coupon = Factory(:coupon) }
#        context "when existing coupon prohibits combination" do
#          setup do
#            @coupon.combine = false
#            @additional_coupon.combine = true
#            @additional_coupon.create_discount(@checkout)
#          end
#          should_change "@coupon.discounts.count", :by => -1
#          should_change "@additional_coupon.discounts.count", :by => 1
#        end
#        context "when additional coupon prohibits combination" do
#          setup do
#            @coupon.combine = true
#            @additional_coupon.combine = false
#            @additional_coupon.create_discount(@checkout)
#          end
#          should_change "@coupon.discounts.count", :by => -1
#          should_change "@additional_coupon.discounts.count", :by => 1
#        end
#        context "when both coupons allow combination" do
#          setup do
#            @coupon.combine = true
#            @additional_coupon.combine = true
#            @additional_coupon.create_discount(@checkout)
#          end
#          should_not_change "@coupon.discounts.count"
#          should_change "@additional_coupon.discounts.count", :by => 1
#        end
#      end
#    end
#    context "when coupon exceeds item total" do
#      setup do
#        @checkout.order.stub!(:item_total, :return => 2)
#        @coupon.calculator.stub!(:calculate_discount, :return => 4)
#      end
#      should "not create a discount greater then item_total" do
#        assert_equal BigDecimal("2"), @coupon.create_discount(@checkout).amount
#      end
#    end
#    context "when expired" do
#      setup do
#        @coupon.expires_at = 3.days.ago
#        @coupon.create_discount(@checkout)
#      end
#      should_not_change "Discount.count"
#    end
#    context "when usage_limit has been exceeded" do
#      setup do
#        @coupon.usage_limit = 0
#        @coupon.create_discount(@checkout)
#      end
#      should_not_change "Discount.count"
#    end
  end
end