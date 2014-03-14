require 'spec_helper'

describe Spree::Promotion do
  let(:promotion) { Spree::Promotion.new }

  describe "validations" do
    before :each do
      @valid_promotion = Spree::Promotion.new :name => "A promotion"
    end

    it "valid_promotion is valid" do
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

  describe "#destroy" do
    let(:promotion) { Spree::Promotion.create(:name => "delete me") }

    before(:each) do
      promotion.actions << Spree::Promotion::Actions::CreateAdjustment.new
      promotion.rules << Spree::Promotion::Rules::FirstOrder.new
      promotion.save!
      promotion.destroy
    end

    it "should delete actions" do
      Spree::PromotionAction.count.should == 0
    end

    it "should delete rules" do
      Spree::PromotionRule.count.should == 0
    end
  end

  describe "#save" do
    let(:promotion) { Spree::Promotion.create(:name => "delete me") }

    before(:each) do
      promotion.actions << Spree::Promotion::Actions::CreateAdjustment.new
      promotion.rules << Spree::Promotion::Rules::FirstOrder.new
      promotion.save!
    end

    it "should deeply autosave records and preferences" do
      promotion.actions[0].calculator.preferred_flat_percent = 10
      promotion.save!
      Spree::Calculator.first.preferred_flat_percent.should == 10
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

    it "does activate if newer then order" do
      @action1.should_receive(:perform).with(@payload)
      promotion.created_at = DateTime.now + 2
      expect(promotion.activate(@payload)).to be_true
    end

    context "keeps track of the orders" do
      context "when activated" do
        it "assigns the order" do
          expect(promotion.orders).to be_empty
          expect(promotion.activate(@payload)).to be_true
          expect(promotion.orders.first).to eql @order
        end
      end
      context "when not activated" do
        it "will not assign the order" do
          @order.state = 'complete'
          expect(promotion.orders).to be_empty
          expect(promotion.activate(@payload)).to be_false
          expect(promotion.orders).to be_empty
        end
      end

    end

  end

  context "#usage_limit_exceeded" do
    let(:promotable) { double('Promotable') }
    it "should not have its usage limit exceeded with no usage limit" do
      promotion.usage_limit = 0
      promotion.usage_limit_exceeded?(promotable).should be_false
    end

    it "should have its usage limit exceeded" do
      promotion.usage_limit = 2
      promotion.stub(:adjusted_credits_count => 2)
      promotion.usage_limit_exceeded?(promotable).should be_true

      promotion.stub(:adjusted_credits_count => 3)
      promotion.usage_limit_exceeded?(promotable).should be_true
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

  context "#credits_count" do
    let!(:promotion) do
      promotion = Spree::Promotion.new
      promotion.name = "Foo"
      promotion.code = "XXX"
      calculator = Spree::Calculator::FlatRate.new
      promotion.tap(&:save)
    end

    let!(:action) do
      calculator = Spree::Calculator::FlatRate.new
      action_params = { :promotion => promotion, :calculator => calculator }
      action = Spree::Promotion::Actions::CreateAdjustment.create(action_params)
      promotion.actions << action
      action
    end

    let!(:adjustment) do
      Spree::Adjustment.create!(
        :source => action,
        :amount => 10,
        :label => "Promotional adjustment"
      )
    end

    it "counts eligible adjustments" do
      adjustment.update_column(:eligible, true)
      expect(promotion.credits_count).to eq(1)
    end

    # Regression test for #4112
    it "does not count ineligible adjustments" do
      adjustment.update_column(:eligible, false)
      expect(promotion.credits_count).to eq(0)
    end
  end

  context "#products" do
    let(:promotion) { create(:promotion) }

    context "when it has product rules with products associated" do
      let(:promotion_rule) { Spree::Promotion::Rules::Product.new }

      before do
        promotion_rule.promotion = promotion
        promotion_rule.products << create(:product)
        promotion_rule.save
      end

      it "should have products" do
        promotion.reload.products.size.should == 1
      end
    end

    context "when there's no product rule associated" do
      before(:each) do
        promotion.stub_chain(:rules, :to_a).and_return([mock_model(Spree::Promotion::Rules::User)])
      end

      it "should not have products but still return an empty array" do
        promotion.products.should be_blank
      end
    end
  end

  context "#eligible?" do
    before do
      @order = create(:order)
      promotion.name = "Foo"
      calculator = Spree::Calculator::FlatRate.new
      action_params = { :promotion => promotion, :calculator => calculator }
      @action = Spree::Promotion::Actions::CreateAdjustment.create(action_params)
    end

    context "when it is expired" do
      before { promotion.stub(:expired? => true) }
      specify { promotion.should_not be_eligible(@order) }
    end

    context "when it is not expired" do
      before { promotion.expires_at = Time.now + 1.day }
      specify { promotion.should be_eligible(@order) }
    end
  end

  context "#rules_are_eligible?" do
    let(:promotable) { double('Promotable') }
    it "true if there are no rules" do
      promotion.rules_are_eligible?(promotable).should be_true
    end

    it "true if there are no applicable rules" do
      promotion.promotion_rules = [mock_model(Spree::PromotionRule, :eligible? => true, :applicable? => false)]
      promotion.promotion_rules.stub(:for).and_return([])
      promotion.rules_are_eligible?(promotable).should be_true
    end

    context "with 'all' match policy" do
      before { promotion.match_policy = 'all' }

      it "should have eligible rules if all rules are eligible" do
        promotion.promotion_rules = [mock_model(Spree::PromotionRule, :eligible? => true, :applicable? => true),
                                     mock_model(Spree::PromotionRule, :eligible? => true, :applicable? => true)]
        promotion.promotion_rules.stub(:for).and_return(promotion.promotion_rules)
        promotion.rules_are_eligible?(promotable).should be_true
      end

      it "should not have eligible rules if any of the rules is not eligible" do
        promotion.promotion_rules = [mock_model(Spree::PromotionRule, :eligible? => true, :applicable? => true),
                                     mock_model(Spree::PromotionRule, :eligible? => false, :applicable? => true)]
        promotion.promotion_rules.stub(:for).and_return(promotion.promotion_rules)
        promotion.rules_are_eligible?(promotable).should be_false
      end
    end

    context "with 'any' match policy" do
      let(:promotion) { Spree::Promotion.create(:name => "Promo", :match_policy => 'any') }
      let(:promotable) { double('Promotable') }

      it "should have eligible rules if any of the rules are eligible" do
        Spree::PromotionRule.any_instance.stub(:applicable? => true)
        true_rule = Spree::PromotionRule.create(:promotion => promotion)
        true_rule.stub(:eligible? => true)
        promotion.stub(:rules => [true_rule])
        promotion.stub_chain(:rules, :for).and_return([true_rule])
        promotion.rules_are_eligible?(promotable).should be_true
      end
    end
  end

  # regression for #4059
  # admin form posts the code and path as empty string
  describe "normalize blank values for code & path" do
    it "will save blank value as nil value instead" do
      promotion = Spree::Promotion.create(:name => "A promotion", :code => "", :path => "")
      expect(promotion.code).to be_nil
      expect(promotion.path).to be_nil
    end
  end

  # Regression test for #4081
  describe "#with_coupon_code" do
    context "and code stored in uppercase" do
      let!(:promotion) { create(:promotion, :code => "MY-COUPON-123") }
      it "finds the code with lowercase" do
        expect(Spree::Promotion.with_coupon_code("my-coupon-123")).to eql promotion
      end
    end
  end
end
