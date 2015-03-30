require 'spec_helper'

describe Spree::Promotion, :type => :model do
  let(:promotion) { Spree::Promotion.new }

  describe "validations" do
    before :each do
      @valid_promotion = Spree::Promotion.new :name => "A promotion"
    end

    it "valid_promotion is valid" do
      expect(@valid_promotion).to be_valid
    end

    it "validates usage limit" do
      @valid_promotion.usage_limit = -1
      expect(@valid_promotion).not_to be_valid

      @valid_promotion.usage_limit = 100
      expect(@valid_promotion).to be_valid
    end

    it "validates name" do
      @valid_promotion.name = nil
      expect(@valid_promotion).not_to be_valid
    end
  end

  describe ".coupons" do
    it "scopes promotions with coupon code present only" do
      promotion = Spree::Promotion.create! name: "test", code: ''
      expect(Spree::Promotion.coupons).to be_empty

      promotion.update_column :code, "check"
      expect(Spree::Promotion.coupons.first).to eq promotion
    end
  end

  describe ".applied" do
    it "scopes promotions that have been applied to an order only" do
      promotion = Spree::Promotion.create! name: "test", code: ''
      expect(Spree::Promotion.applied).to be_empty

      promotion.orders << create(:order)
      expect(Spree::Promotion.applied.first).to eq promotion
    end
  end

  describe ".advertised" do
    let(:promotion) { create(:promotion) }
    let(:advertised_promotion) { create(:promotion, :advertise => true) }

    it "only shows advertised promotions" do
      advertised = Spree::Promotion.advertised
      expect(advertised).to include(advertised_promotion)
      expect(advertised).not_to include(promotion)
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
      expect(Spree::PromotionAction.count).to eq(0)
    end

    it "should delete rules" do
      expect(Spree::PromotionRule.count).to eq(0)
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
      expect(Spree::Calculator.first.preferred_flat_percent).to eq(10)
    end
  end

  describe "#activate" do
    before do
      @action1 = Spree::Promotion::Actions::CreateAdjustment.create!
      @action2 = Spree::Promotion::Actions::CreateAdjustment.create!
      allow(@action1).to receive_messages perform: true
      allow(@action2).to receive_messages perform: true

      promotion.promotion_actions = [@action1, @action2]
      promotion.created_at = 2.days.ago

      @user = stub_model(Spree::LegacyUser, :email => "spree@example.com")
      @order = Spree::Order.create user: @user
      @payload = { :order => @order, :user => @user }
    end

    it "should check path if present" do
      promotion.path = 'content/cvv'
      @payload[:path] = 'content/cvv'
      expect(@action1).to receive(:perform).with(@payload)
      expect(@action2).to receive(:perform).with(@payload)
      promotion.activate(@payload)
    end

    it "does not perform actions against an order in a finalized state" do
      expect(@action1).not_to receive(:perform).with(@payload)

      @order.state = 'complete'
      promotion.activate(@payload)

      @order.state = 'awaiting_return'
      promotion.activate(@payload)

      @order.state = 'returned'
      promotion.activate(@payload)
    end

    it "does activate if newer then order" do
      expect(@action1).to receive(:perform).with(@payload)
      promotion.created_at = DateTime.now + 2
      expect(promotion.activate(@payload)).to be true
    end

    context "keeps track of the orders" do
      context "when activated" do
        it "assigns the order" do
          expect(promotion.orders).to be_empty
          expect(promotion.activate(@payload)).to be true
          expect(promotion.orders.first).to eql @order
        end
      end
      context "when not activated" do
        it "will not assign the order" do
          @order.state = 'complete'
          expect(promotion.orders).to be_empty
          expect(promotion.activate(@payload)).to be_falsey
          expect(promotion.orders).to be_empty
        end
      end

    end

  end

  context "#usage_limit_exceeded" do
    let(:promotable) { double('Promotable') }
    it "should not have its usage limit exceeded with no usage limit" do
      promotion.usage_limit = 0
      expect(promotion.usage_limit_exceeded?(promotable)).to be false
    end

    it "should have its usage limit exceeded" do
      promotion.usage_limit = 2
      allow(promotion).to receive_messages(:adjusted_credits_count => 2)
      expect(promotion.usage_limit_exceeded?(promotable)).to be true

      allow(promotion).to receive_messages(:adjusted_credits_count => 3)
      expect(promotion.usage_limit_exceeded?(promotable)).to be true
    end
  end

  context "#expired" do
    it "should not be exipired" do
      expect(promotion).not_to be_expired
    end

    it "should be expired if it hasn't started yet" do
      promotion.starts_at = Time.now + 1.day
      expect(promotion).to be_expired
    end

    it "should be expired if it has already ended" do
      promotion.expires_at = Time.now - 1.day
      expect(promotion).to be_expired
    end

    it "should not be expired if it has started already" do
      promotion.starts_at = Time.now - 1.day
      expect(promotion).not_to be_expired
    end

    it "should not be expired if it has not ended yet" do
      promotion.expires_at = Time.now + 1.day
      expect(promotion).not_to be_expired
    end

    it "should not be expired if current time is within starts_at and expires_at range" do
      promotion.starts_at  = Time.now - 1.day
      promotion.expires_at = Time.now + 1.day
      expect(promotion).not_to be_expired
    end

    it "should not be expired if usage limit is not exceeded" do
      promotion.usage_limit = 2
      allow(promotion).to receive_messages(:credits_count => 1)
      expect(promotion).not_to be_expired
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
      order = create(:order)
      Spree::Adjustment.create!(
        order:      order,
        adjustable: order,
        source:     action,
        amount:     10,
        label:      'Promotional adjustment'
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

  context "#adjusted_credits_count" do
    let(:order) { create :order }
    let(:line_item) { create :line_item, order: order }
    let(:promotion) { Spree::Promotion.create name: "promo", :code => "10off" }
    let(:order_action) {
      action = Spree::Promotion::Actions::CreateAdjustment.create(calculator: Spree::Calculator::FlatPercentItemTotal.new)
      promotion.actions << action
      action
    }
    let(:item_action) {
      action = Spree::Promotion::Actions::CreateItemAdjustments.create(calculator: Spree::Calculator::FlatPercentItemTotal.new)
      promotion.actions << action
      action
    }
    let(:order_adjustment) do
      Spree::Adjustment.create!(
        :source => order_action,
        :amount => 10,
        :adjustable => order,
        :order => order,
        :label => "Promotional adjustment"
      )
    end
    let(:item_adjustment) do
      Spree::Adjustment.create!(
        :source => item_action,
        :amount => 10,
        :adjustable => line_item,
        :order => order,
        :label => "Promotional adjustment"
      )
    end

    it "counts order level adjustments" do
      expect(order_adjustment.adjustable).to eq(order)
      expect(promotion.credits_count).to eq(1)
      expect(promotion.adjusted_credits_count(order)).to eq(0)
    end

    it "counts item level adjustments" do
      expect(item_adjustment.adjustable).to eq(line_item)
      expect(promotion.credits_count).to eq(1)
      expect(promotion.adjusted_credits_count(order)).to eq(0)
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
        expect(promotion.reload.products.size).to eq(1)
      end
    end

    context "when there's no product rule associated" do
      it "should not have products but still return an empty array" do
        expect(promotion.products).to be_blank
      end
    end
  end

  context "#eligible?" do
    let(:promotable) { create :order }
    subject { promotion.eligible?(promotable) }
    context "when promotion is expired" do
      before { promotion.expires_at = Time.now - 10.days }
      it { is_expected.to be false }
    end
    context "when promotable is a Spree::LineItem" do
      let(:promotable) { create :line_item }
      let(:product) { promotable.product }
      before do
        product.promotionable = promotionable
      end
      context "and product is promotionable" do
        let(:promotionable) { true }
        it { is_expected.to be true }
      end
      context "and product is not promotionable" do
        let(:promotionable) { false }
        it { is_expected.to be false }
      end
    end
    context "when promotable is a Spree::Order" do
      let(:promotable) { create :order }
      context "and it is empty" do
        it { is_expected.to be true }
      end
      context "and it contains items" do
        let!(:line_item) { create(:line_item, order: promotable) }
        context "and the items are all non-promotionable" do
          before do
            line_item.product.update_column(:promotionable, false)
          end
          it { is_expected.to be false }
        end
        context "and at least one item is promotionable" do
          it { is_expected.to be true }
        end
      end
    end
  end

  context "#eligible_rules" do
    let(:promotable) { double('Promotable') }
    it "true if there are no rules" do
      expect(promotion.eligible_rules(promotable)).to eq []
    end

    it "true if there are no applicable rules" do
      promotion.promotion_rules = [stub_model(Spree::PromotionRule, :eligible? => true, :applicable? => false)]
      allow(promotion.promotion_rules).to receive(:for).and_return([])
      expect(promotion.eligible_rules(promotable)).to eq []
    end

    context "with 'all' match policy" do
      let(:promo1) { Spree::PromotionRule.create! }
      let(:promo2) { Spree::PromotionRule.create! }

      before { promotion.match_policy = 'all' }

      context "when all rules are eligible" do
        before do
          allow(promo1).to receive_messages(eligible?: true, applicable?: true)
          allow(promo2).to receive_messages(eligible?: true, applicable?: true)

          promotion.promotion_rules = [promo1, promo2]
          allow(promotion.promotion_rules).to receive(:for).and_return(promotion.promotion_rules)
        end
        it "returns the eligible rules" do
          expect(promotion.eligible_rules(promotable)).to eq [promo1, promo2]
        end
        it "does set anything to eligiblity errors" do
          promotion.eligible_rules(promotable)
          expect(promotion.eligibility_errors).to be_nil
        end
      end

      context "when any of the rules is not eligible" do
        let(:errors) { double ActiveModel::Errors, empty?: false }
        before do
          allow(promo1).to receive_messages(eligible?: true, applicable?: true, eligibility_errors: nil)
          allow(promo2).to receive_messages(eligible?: false, applicable?: true, eligibility_errors: errors)

          promotion.promotion_rules = [promo1, promo2]
          allow(promotion.promotion_rules).to receive(:for).and_return(promotion.promotion_rules)
        end
        it "returns nil" do
          expect(promotion.eligible_rules(promotable)).to be_nil
        end
        it "sets eligibility errors to the first non-nil one" do
          promotion.eligible_rules(promotable)
          expect(promotion.eligibility_errors).to eq errors
        end
      end
    end

    context "with 'any' match policy" do
      let(:promotion) { Spree::Promotion.create(:name => "Promo", :match_policy => 'any') }
      let(:promotable) { double('Promotable') }

      it "should have eligible rules if any of the rules are eligible" do
        allow_any_instance_of(Spree::PromotionRule).to receive_messages(:applicable? => true)
        true_rule = Spree::PromotionRule.create(:promotion => promotion)
        allow(true_rule).to receive_messages(:eligible? => true)
        allow(promotion).to receive_messages(:rules => [true_rule])
        allow(promotion).to receive_message_chain(:rules, :for).and_return([true_rule])
        expect(promotion.eligible_rules(promotable)).to eq [true_rule]
      end

      context "when none of the rules are eligible" do
        let(:promo) { Spree::PromotionRule.create! }
        let(:errors) { double ActiveModel::Errors, empty?: false }
        before do
          allow(promo).to receive_messages(eligible?: false, applicable?: true, eligibility_errors: errors)

          promotion.promotion_rules = [promo]
          allow(promotion.promotion_rules).to receive(:for).and_return(promotion.promotion_rules)
        end
        it "returns nil" do
          expect(promotion.eligible_rules(promotable)).to be_nil
        end
        it "sets eligibility errors to the first non-nil one" do
          promotion.eligible_rules(promotable)
          expect(promotion.eligibility_errors).to eq errors
        end
      end
    end
  end

  describe '#line_item_actionable?' do
    let(:order) { double Spree::Order }
    let(:line_item) { double Spree::LineItem}
    let(:true_rule) { double Spree::PromotionRule, eligible?: true, applicable?: true, actionable?: true }
    let(:false_rule) { double Spree::PromotionRule, eligible?: true, applicable?: true, actionable?: false }
    let(:rules) { [] }

    before do
      allow(promotion).to receive(:rules) { rules }
      allow(rules).to receive(:for) { rules }
    end

    subject { promotion.line_item_actionable? order, line_item }

    context 'when the order is eligible for promotion' do
      context 'when there are no rules' do
        it { is_expected.to be }
      end

      context 'when there are rules' do
        context 'when the match policy is all' do
          before { promotion.match_policy = 'all' }

          context 'when all rules allow action on the line item' do
            let(:rules) { [true_rule] }
            it { is_expected.to be}
          end

          context 'when at least one rule does not allow action on the line item' do
            let(:rules) { [true_rule, false_rule] }
            it { is_expected.not_to be}
          end
        end

        context 'when the match policy is any' do
          before { promotion.match_policy = 'any' }

          context 'when at least one rule allows action on the line item' do
            let(:rules) { [true_rule, false_rule] }
            it { is_expected.to be }
          end

          context 'when no rules allow action on the line item' do
            let(:rules) { [false_rule] }
            it { is_expected.not_to be}
          end
        end
      end
    end

      context 'when the order is not eligible for the promotion' do
        before { promotion.starts_at = Time.current + 2.days }
        it { is_expected.not_to be }
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

  describe '#used_by?' do
    subject { promotion.used_by? user, [excluded_order] }

    let(:promotion) { create :promotion, :with_order_adjustment }
    let(:user) { create :user }
    let(:order) { create :order_with_line_items, user: user }
    let(:excluded_order) { create :order_with_line_items, user: user }

    before do
      order.user_id = user.id
      order.save!
    end

    context 'when the user has used this promo' do
      before do
        promotion.activate(order: order)
        order.update!
        order.completed_at = Time.now
        order.save!
      end

      context 'when the order is complete' do
        it { is_expected.to be true }

        context 'when the promotion was not eligible' do
          let(:adjustment) { order.adjustments.first }

          before do
            adjustment.eligible = false
            adjustment.save!
          end

          it { is_expected.to be false }
        end

        context 'when the only matching order is the excluded order' do
          let(:excluded_order) { order }
          it { is_expected.to be false }
        end
      end

      context 'when the order is not complete' do
        let(:order) { create :order, user: user }
        it { is_expected.to be false }
      end
    end

    context 'when the user has not used this promo' do
      it { is_expected.to be false }
    end
  end

  describe "adding items to the cart" do
    let(:order) { create :order }
    let(:line_item) { create :line_item, order: order }
    let(:promo) { create :promotion_with_item_adjustment, adjustment_rate: 5, code: 'promo' }
    let(:variant) { create :variant }

    it "updates the promotions for new line items" do
      expect(line_item.adjustments).to be_empty
      expect(order.adjustment_total).to eq 0

      promo.activate order: order
      order.update!

      expect(line_item.adjustments.size).to eq(1)
      expect(order.adjustment_total).to eq -5

      other_line_item = order.contents.add(variant, 1, currency: order.currency)

      expect(other_line_item).not_to eq line_item
      expect(other_line_item.adjustments.size).to eq(1)
      expect(order.adjustment_total).to eq -10
    end
  end
end
