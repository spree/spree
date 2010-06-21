require 'test_helper'

class CouponTest < ActiveSupport::TestCase
  should_validate_presence_of :code
  
  context "instance" do
    setup do
      @checkout = Factory(:checkout)
      @coupon = Factory(:coupon)
    end
    
    context "expires_at < now" do
      setup { @coupon.expires_at = Time.now - 1.day }
      should "not be eligible" do
        assert !@coupon.eligible?(Factory(:order))
      end
    end
    
    context "expires_at > now" do
      setup { @coupon.expires_at = Time.now + 1.day }
      should "be eligible" do
        assert @coupon.eligible?(Factory(:order))
      end
    end
    
    context "with usage limit of 1" do
      setup { @coupon.usage_limit = 1 }
      context "when coupon has already been used" do
        setup { @coupon.create_discount(Factory(:order)) }
        should "not be eligible" do
          assert !@coupon.eligible?(Factory(:order))
        end
      end
      context "when coupon has not yet been used" do
        should "be eligible" do
          assert @coupon.eligible?(Factory(:order))
        end
      end
    end
    
    context "with starts_at > now" do
      setup { @coupon.starts_at = Time.now + 1.day }
      should "not be eligible" do
        assert !@coupon.eligible?(Factory(:order))
      end
    end

    context "with starts_at < now" do
      setup { @coupon.starts_at = Time.now - 1.day }
      should "be eligible" do
        assert @coupon.eligible?(Factory(:order))
      end
    end
    
  end
end