require 'spec_helper'

describe Spree::Promotion do
  let(:promotion) { Spree::Promotion.new }

  describe "#save" do
    let(:promotion_valid) { Spree::Promotion.new :name => "A promotion", :code => "XXXX" }

    it "should validate the coupon code" do
      pending "Figure out some form of validation for codes now that this is Promo preference"
    end

    context "when is invalid" do
      before { promotion.name = nil }
      it { promotion.save.should be_false }
    end

    context "when is valid" do
      it { promotion_valid.save.should be_true }

      it "should have the right key in preferences" do
        promotion_valid.save.should be_true
        Spree::Preference.last.key.should_not eql('spree/promotion/code/new')
        Spree::Preference.last.key.should eql("spree/promotion/code/#{promotion_valid.id}")
      end
    end
  end

  describe "#delete" do
    it "deletes actions" do
      p = Spree::Promotion.create(:name => "delete me")
      p.actions << Spree::Promotion::Actions::CreateAdjustment.new
      p.destroy

      Spree::PromotionAction.count.should == 0
    end

    it "deletes rules" do
      p = Spree::Promotion.create(:name => "delete me")
      p.rules << Spree::Promotion::Rules::FirstOrder.new
      p.destroy

      Spree::PromotionRule.count.should == 0
    end

  end

  describe "#activate" do
    before do
      @action1 = mock_model(Spree::PromotionAction, :perform => true)
      @action2 = mock_model(Spree::PromotionAction, :perform => true)
      promotion.promotion_actions = [@action1, @action2]
    end

    context "when checking coupon_is_eligible?" do
      it "should accommodate promotions that are not attached to orders" do
        lambda {promotion.activate(:order => nil, :user => nil)}.should_not raise_error
      end
    end

    context "when eligible?" do
      before do
        promotion.stub(:eligible? => true)
      end
      it "should perform all actions" do
        @action1.should_receive(:perform)
        @action2.should_receive(:perform)
        promotion.activate(:order => nil, :user => nil)
      end
    end
    context "when not eligible?" do
      before do
        promotion.stub(:eligible? => false)
      end
      it "should not perform any actions" do
        @action1.should_not_receive(:perform)
        @action2.should_not_receive(:perform)
        promotion.activate(:order => nil, :user => nil)
      end
    end
  end

  context "#usage_limit_exceeded" do
     it "should not have its usage limit exceeded" do
       promotion.should_not be_usage_limit_exceeded
     end

     it "should have its usage limit exceeded" do
       promotion.preferred_usage_limit = 2
       promotion.stub(:credits_count => 2)
       promotion.usage_limit_exceeded?.should == true

       promotion.stub(:credits_count => 3)
       promotion.usage_limit_exceeded?.should == true
     end
   end

  context "#expired" do
    it "should not be exipired" do
      promotion.should_not be_expired
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

  context "#eligible?" do
    before do
      @order = Factory(:order)
      promotion.preferred_code = 'ABC'
      promotion.event_name = 'spree.checkout.coupon_code_added'
      promotion.name = "Foo"
      calculator = Spree::Calculator::FlatRate.new
      @action = Spree::Promotion::Actions::CreateAdjustment.create(:promotion => promotion, :calculator => calculator)
    end

    context "when it is expired" do
      before { promotion.stub(:expired? => true) }

      specify { promotion.should_not be_eligible(@order) }
    end

    context "when it is not expired" do
      before { promotion.expires_at = Time.now + 1.day }

      specify { promotion.should be_eligible(@order) }
    end

    context "when activated by coupon code event and a code is set" do
      before do
        promotion.event_name = 'spree.checkout.coupon_code_added'
        promotion.preferred_code = 'ABC'
      end

      it "is false when payload doesn't include the matching code" do
        promotion.should_not be_eligible(@order, {})
      end

      it "is true when payload includes the matching code" do
        promotion.should be_eligible(@order, {:coupon_code => 'ABC'})
      end
    end

    context "when a coupon code has already resulted in an adjustment on the order" do
      before do
        promotion.save!
        @order.adjustments.create(:amount => 1,
                                  :source => @order,
                                  :originator => @action,
                                  :label => "Foo")
      end

      it "should be eligible" do
        promotion.should be_eligible(@order)
      end
    end

  end

  context "rules" do
    before { @order = Spree::Order.new }

    it "should have eligible rules if there are no rules" do
      promotion.rules_are_eligible?(@order).should be_true
    end

    context "with 'all' match policy" do
      before { promotion.match_policy = 'all' }

      it "should have eligible rules if all rules are eligible" do
        promotion.promotion_rules = [mock_model(Spree::PromotionRule, :eligible? => true),
                                     mock_model(Spree::PromotionRule, :eligible? => true)]
        promotion.rules_are_eligible?(@order).should be_true
      end

      it "should not have eligible rules if any of the rules is not eligible" do
        promotion.promotion_rules = [mock_model(Spree::PromotionRule, :eligible? => true),
                                     mock_model(Spree::PromotionRule, :eligible? => false)]
        promotion.rules_are_eligible?(@order).should be_false
      end
    end

    context "with 'any' match policy" do
      before(:each) do
        @promotion = Spree::Promotion.new(:name => "Promo", :match_policy => 'any')
        @promotion.save
      end

      it "should have eligible rules if any of the rules is eligible" do
        true_rule = Spree::PromotionRule.create(:promotion => @promotion)
        true_rule.stub(:eligible?).and_return(true)
        false_rule = Spree::PromotionRule.create(:promotion => @promotion)
        false_rule.stub(:eligible?).and_return(false)
        @promotion.rules << true_rule
        @promotion.rules_are_eligible?(@order).should be_true
      end
    end

  end

end
