require 'spec_helper'

describe Promotion do
  subject { Promotion.new }

  context "creating discounts" do
    before do
      @order = Fabricate(:order)
      @promotion = Fabricate(:promotion)
      @promotion.calculator = Calculator::FreeShipping.new
    end

    it "should not create a discount when order is not eligible" do
      @promotion.stub(:eligible? => false)

      @promotion.create_discount(@order)
      @order.promotion_credits.should have(0).item
    end

    it "should be able to create a discount on order" do
      @order.stub(:line_items => [mock_model(LineItem, :amount => 50)],
                  :ship_total => 5)

      Fabricate(:adjustment, :amount => 5, :label => I18n.t(:shipping), :order => @order)

      @order.update_totals
      rule = Promotion::Rules::FirstOrder.new
      rule.stub(:eligible? => true)
      @promotion.rules << rule

      @order.total.to_f.should == 55
      @promotion.create_discount(@order)
      @order.total.to_f.should == 50
    end
  end

  context "#expired" do
    it "should not be exipired" do
      subject.should_not be_expired
    end

    it "should be expired if usage limit is exceeded" do
      subject.usage_limit = 2
      subject.stub(:credits_count => 2)
      subject.should be_expired

      subject.stub(:credits_count => 3)
      subject.should be_expired
    end

    it "should be expired if it hasn't started yet" do
      subject.starts_at = Time.now + 1.day
      subject.should be_expired
    end

    it "should be expired if it has already ended" do
      subject.expires_at = Time.now - 1.day
      subject.should be_expired
    end

    it "should not be expired if it has started already" do
      subject.starts_at = Time.now - 1.day
      subject.should_not be_expired
    end

    it "should not be expired if it has not ended yet" do
      subject.expires_at = Time.now + 1.day
      subject.should_not be_expired
    end

    it "should not be expired if current time is within starts_at and expires_at range" do
      subject.expires_at = Time.now - 1.day
      subject.expires_at = Time.now + 1.day
      subject.should_not be_expired
    end

    it "should not be expired if usage limit is not exceeded" do
      subject.usage_limit = 2
      subject.stub(:credits_count => 1)
      subject.should_not be_expired
    end
  end

  context "eligible?" do
    before { @order = Order.new }

    context "when it is expired" do
      before { subject.stub(:expired? => true) }

      specify { subject.should_not be_eligible(@order) }
    end

    context "when it is not expired" do
      before { subject.stub(:expired? => false) }

      specify { subject.should be_eligible(@order) }
    end
  end

  context "rules" do
    before { @order = Order.new }

    it "should have eligible rules if there are no rules" do
      subject.rules_are_eligible?(@order).should be_true
    end

    context "with 'all' match policy" do
      before { subject.match_policy = 'all' }

      it "should have eligible rules if all rules are eligible" do
        rule = mock_model(PromotionRule, :eligible? => true)
        subject.promotion_rules = [rule, rule.clone]

        subject.rules_are_eligible?(@order).should be_true
      end

      it "should not have eligible rules if any of the rules is not eligible" do
        subject.promotion_rules = [mock_model(PromotionRule, :eligible? => true),
                                   mock_model(PromotionRule, :eligible? => false)]

        subject.rules_are_eligible?(@order).should be_false
      end
    end

    context "with 'any' match policy" do
      before { subject.match_policy = 'any' }

      it "should have eligible rules if any of the rules is eligible" do
        
        rule = PromotionRule.new
        rule.stub(:eligible? => true)
        rule1 = PromotionRule.new
        rule1.stub(:eligible? => false)
        rules = [rule, rule1]
        subject.promotion_rules = rules

        subject.rules_are_eligible?(@order).should be_true
      end
    end
  end
end
