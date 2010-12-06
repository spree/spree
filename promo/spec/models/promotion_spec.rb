require 'spec_helper'

describe Promotion do
  let(:promotion) { Promotion.new }

  context "creating discounts" do
    before do
      @order = Fabricate(:order)
      promotion.calculator = Calculator::FreeShipping.new
    end

    it "should not create a discount when order is not eligible" do
      promotion.stub(:eligible? => false)

      promotion.create_discount(@order)
      @order.promotion_credits.should have(0).item
    end

    it "should be able to create a discount on order" do
      @order.stub(:line_items => [mock_model(LineItem, :amount => 50)],
                  :ship_total => 5)

      Fabricate(:adjustment, :amount => 5, :label => I18n.t(:shipping), :order => @order)

      @order.update_totals
      rule = Promotion::Rules::FirstOrder.new
      rule.stub(:eligible? => true)
      promotion.rules << rule

      @order.total.to_f.should == 55
      promotion.create_discount(@order)
      @order.total.to_f.should == 50
    end
  end

  context "#expired" do
    it "should not be exipired" do
      promotion.should_not be_expired
    end

    it "should be expired if usage limit is exceeded" do
      promotion.usage_limit = 2
      promotion.stub(:credits_count => 2)
      promotion.should be_expired

      promotion.stub(:credits_count => 3)
      promotion.should be_expired
    end

    it "should be expired if it hasn't started yet" do
      promotion.starts_at = Time.now + 1.day
      promotion.should be_expired
    end

    it "should be expired if it has already ended" do
      promotion.expires_at = Time.now - 1.day
      promotion.should be_expired
    end

    it "should not be expired if it has started already" do
      promotion.starts_at = Time.now - 1.day
      promotion.should_not be_expired
    end

    it "should not be expired if it has not ended yet" do
      promotion.expires_at = Time.now + 1.day
      promotion.should_not be_expired
    end

    it "should not be expired if current time is within starts_at and expires_at range" do
      promotion.expires_at = Time.now - 1.day
      promotion.expires_at = Time.now + 1.day
      promotion.should_not be_expired
    end

    it "should not be expired if usage limit is not exceeded" do
      promotion.usage_limit = 2
      promotion.stub(:credits_count => 1)
      promotion.should_not be_expired
    end
  end

  context "eligible?" do
    before { @order = Order.new }

    context "when it is expired" do
      before { promotion.stub(:expired? => true) }

      specify { promotion.should_not be_eligible(@order) }
    end

    context "when it is not expired" do
      before { promotion.stub(:expired? => false) }

      specify { promotion.should be_eligible(@order) }
    end
  end

  context "rules" do
    before { @order = Order.new }

    it "should have eligible rules if there are no rules" do
      promotion.rules_are_eligible?(@order).should be_true
    end

    context "with 'all' match policy" do
      before { promotion.match_policy = 'all' }

      it "should have eligible rules if all rules are eligible" do
        rule = mock_model(PromotionRule, :eligible? => true)
        promotion.promotion_rules = [rule, rule.clone]

        promotion.rules_are_eligible?(@order).should be_true
      end

      it "should not have eligible rules if any of the rules is not eligible" do
        promotion.promotion_rules = [mock_model(PromotionRule, :eligible? => true),
                                     mock_model(PromotionRule, :eligible? => false)]

        promotion.rules_are_eligible?(@order).should be_false
      end
    end

    context "with 'any' match policy" do
      before { promotion.match_policy = 'any' }

      it "should have eligible rules if any of the rules is eligible" do
        promotion.promotion_rules = [mock_model(PromotionRule, :eligible? => true),
                                     mock_model(PromotionRule, :eligible? => false)]

        promotion.rules_are_eligible?(@order).should be_true
      end
    end
  end
end
