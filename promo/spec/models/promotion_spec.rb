require 'spec_helper'

describe Spree::Promotion do
  let(:promotion) { Spree::Promotion.new }

  describe "validations" do
    before :each do
      @valid_promotion = Spree::Promotion.new :name => "A promotion",
                                              :event_name => 'spree.checkout.coupon_code_added',
                                              :code => 'XXX'
    end

    it "valid_promotion is valid" do
      @valid_promotion.should be_valid
    end

    it "validates the coupon code when event is spree.checkout.coupon_code_added" do
      @valid_promotion.code = nil
      @valid_promotion.should_not be_valid
    end

    it "validates the path when event is spree.content.visited" do
      @valid_promotion.event_name = 'spree.content.visited'
      @valid_promotion.should_not be_valid

      @valid_promotion.path = 'content/cvv'
      @valid_promotion.should be_valid
    end

    it "validates usage limit" do
      @valid_promotion.usage_limit = -1
      @valid_promotion.should_not be_valid

      @valid_promotion.usage_limit = 100
      @valid_promotion.should be_valid
    end

    it "validates name" do
      @valid_promotion.name = nil
      @valid_promotion.should_not be_valid
    end

  end

  describe ".advertised" do
    let(:promotion) { create(:promotion) }
    let(:advertised_promotion) { create(:promotion, :advertise => true) }

    it "only shows advertised promotions" do
      advertised = Spree::Promotion.advertised
      advertised.should include(advertised_promotion)
      advertised.should_not include(promotion)
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
      promotion.created_at = 2.days.ago

      @user = stub_model(Spree::LegacyUser, :email => "spree@example.com")
      @order = stub_model(Spree::Order, :user => @user, :created_at => DateTime.now)
      @payload = { :order => @order, :user => @user }
    end

    it "should check code if present" do
      promotion.code = 'xxx'
      @payload[:coupon_code] = 'xxx'
      @action1.should_receive(:perform).with(@payload)
      @action2.should_receive(:perform).with(@payload)
      promotion.activate(@payload)
    end

    it "should check path if present" do
      promotion.path = 'content/cvv'
      @payload[:path] = 'content/cvv'
      @action1.should_receive(:perform).with(@payload)
      @action2.should_receive(:perform).with(@payload)
      promotion.activate(@payload)
    end

    it "does not perform actions against an order in a finalized state" do
      @action1.should_not_receive(:perform).with(@payload)

      @order.state = 'complete'
      promotion.activate(@payload)

      @order.state = 'awaiting_return'
      promotion.activate(@payload)

      @order.state = 'returned'
      promotion.activate(@payload)
    end

    it "does not activate if newer then order" do
      @action1.should_not_receive(:perform).with(@payload)
      promotion.created_at = DateTime.now + 2
      promotion.activate(@payload)
    end
  end

  context "#usage_limit_exceeded" do
     it "should not have its usage limit exceeded" do
       promotion.should_not be_usage_limit_exceeded
     end

     it "should have its usage limit exceeded" do
       promotion.usage_limit = 2
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

  context "#products" do
    context "when it has product rules with products associated" do
      let(:promotion) { create(:promotion) }

      before do
        promotion_rule = Spree::Promotion::Rules::Product.new
        promotion_rule.promotion = promotion
        promotion_rule.products << create(:product)
        promotion_rule.save
      end

      it "should have products" do
        promotion.products.size.should == 1
      end
    end
  end

  context "#eligible?" do
    before do
      @order = create(:order)
      promotion.event_name = 'spree.checkout.coupon_code_added'
      promotion.name = "Foo"
      promotion.code = "XXX"
      calculator = Spree::Calculator::FlatRate.new
      action_params = { :promotion => promotion, :calculator => calculator }
      @action = Spree::Promotion::Actions::CreateAdjustment.create(action_params, :without_protection => true)
    end

    context "when it is expired" do
      before { promotion.stub(:expired? => true) }

      specify { promotion.should_not be_eligible(@order) }
    end

    context "when it is not expired" do
      before { promotion.expires_at = Time.now + 1.day }

      specify { promotion.should be_eligible(@order) }
    end

    context "when a coupon code has already resulted in an adjustment on the order" do
      before do
        promotion.save!

        @order.adjustments.create({:amount => 1,
                                  :source => @order,
                                  :originator => @action,
                                  :label => "Foo"}, :without_protection => true)
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
        true_rule = Spree::PromotionRule.create({:promotion => @promotion}, :without_protection => true)
        true_rule.stub(:eligible?).and_return(true)
        false_rule = Spree::PromotionRule.create({:promotion => @promotion}, :without_protection => true)
        false_rule.stub(:eligible?).and_return(false)
        @promotion.rules << true_rule
        @promotion.rules_are_eligible?(@order).should be_true
      end
    end

  end

end
