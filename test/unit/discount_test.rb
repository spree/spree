require 'test_helper'

class DiscountTest < ActiveSupport::TestCase
  should_validate_presence_of :checkout_id
  should_validate_presence_of :coupon_id 
  
  context "given a valid coupon" do
    setup do
       TestCouponCalc.stub!(:test_amount, :return => 1.50 )
    end
    context "instance" do
      setup do
        @discount = Factory.build(:discount) 
      end
      context "save" do
        setup { @discount.save }
        should "create a credit with the amount returned by the coupon" do
          assert_equal BigDecimal("1.50"), Credit.last.amount
        end
      end 
    end
    context "existing instance" do
      setup { @discount = Factory(:discount) }
      context "save" do
        setup { @discount.save}
        should_not_change "Credit.count"
      end  
      context "save with new coupon amount" do
        setup do
          TestCouponCalc.stub!(:test_amount, :return => 1.00 )
          @discount.save
        end
        should_not_change "Credit.count"
        should "update existing credit with the revised amount" do
          assert_equal BigDecimal("1.00"), @discount.credit.amount
        end
      end
      context "save when coupon no longer valid" do
        setup do                             
          @discount.coupon.expires_at = Time.now - 1.day
          @discount.save
        end
        should "delete the existing discount" do
          assert @discount.frozen?
        end
        should_change "Credit.count", :by => -1        
      end
    end
  end
end
