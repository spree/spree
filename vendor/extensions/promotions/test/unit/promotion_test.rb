require 'test_helper'

class PromotionTest < ActiveSupport::TestCase

  context "instance" do
    setup do
      @checkout = Factory(:checkout)
      @promotion = Factory(:promotion)

      @order = Factory(:order)
      
      @eligible_rule = PromotionRule.new()
      @eligible_rule.stub!(:eligible?, :return => true)
      @not_eligible_rule = PromotionRule.new()
      @not_eligible_rule.stub!(:eligible?, :return => false)
    end
    
    context "expired?" do
      context "expires_at < now" do
        setup { @promotion.expires_at = Time.now - 1.day }
        should "not be expired" do
          assert @promotion.expired?
        end
      end
      context "expires_at > now" do
        setup { @promotion.expires_at = Time.now + 1.day }
        should "not be expired" do
          assert !@promotion.expired?
        end
      end
      context "with usage limit of 1" do
        setup { @promotion.usage_limit = 1 }
        context "when coupon has already been used" do
          setup { @promotion.create_discount(Factory(:order)) }
          should "be expired" do
            assert @promotion.expired?
          end
        end
        context "when coupon has not yet been used" do
          should "not be expired" do
            assert !@promotion.expired?
          end
        end
      end
      context "with starts_at > now" do
        setup { @promotion.starts_at = Time.now + 1.day }
        should "be expired" do
          assert @promotion.expired?
        end
      end
      context "with starts_at < now" do
        setup { @promotion.starts_at = Time.now - 1.day }
        should "not be expired" do
          assert !@promotion.expired?
        end
      end
    end
  

    context "rules_are_eligible?" do
      context "with no rules" do
        should "be true" do
          assert @promotion.rules_are_eligible?(@order)
        end
      end
      context "with 1 matching rule out of 2" do
        setup do
          @promotion.promotion_rules = [
            @eligible_rule,
            @not_eligible_rule
          ]
        end
        context "and match_policy all" do
          setup { @promotion.match_policy = 'all'}
          should "be false" do
            assert !@promotion.rules_are_eligible?(@order)
          end
        end
        context "and match_policy any" do
          setup { @promotion.match_policy = 'any'}
          should "be true" do
            assert @promotion.rules_are_eligible?(@order)
          end
        end
      end
    end
    
  end
end