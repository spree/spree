require 'spec_helper'

describe Spree::Promotion, type: :model do
  let(:promotion) { Spree::Promotion.new }

  describe 'validations' do
    before do
      @valid_promotion = Spree::Promotion.new name: 'A promotion'
    end

    it 'valid_promotion is valid' do
      expect(@valid_promotion).to be_valid
    end

    it 'validates usage limit' do
      @valid_promotion.usage_limit = -1
      expect(@valid_promotion).not_to be_valid

      @valid_promotion.usage_limit = 100
      expect(@valid_promotion).to be_valid
    end

    it 'validates name' do
      @valid_promotion.name = nil
      expect(@valid_promotion).not_to be_valid
    end

    describe 'expires_at_must_be_later_than_starts_at' do
      before do
        @valid_promotion.starts_at = Date.today
      end

      context 'starts_at is a date earlier than expires_at' do
        before { @valid_promotion.expires_at = 5.days.from_now }

        it 'is valid' do
          expect(@valid_promotion).to be_valid
        end
      end

      context 'starts_at is a date earlier than expires_at' do
        before { @valid_promotion.expires_at = 5.days.ago }

        context 'is not valid' do
          before { @valid_promotion.valid? }
          it { expect(@valid_promotion).not_to be_valid }
          it { expect(@valid_promotion.errors[:expires_at]).to include(I18n.t(:invalid_date_range, scope: 'activerecord.errors.models.spree/promotion.attributes.expires_at')) }
        end
      end

      context 'starts_at and expires_at are nil' do
        before do
          @valid_promotion.expires_at = nil
          @valid_promotion.starts_at = nil
        end

        it 'is valid' do
          expect(@valid_promotion).to be_valid
        end
      end
    end
  end

  describe 'scopes' do
    describe '.coupons' do
      subject { Spree::Promotion.coupons }

      let!(:promotion_without_code) { Spree::Promotion.create! name: 'test', code: '' }
      let!(:promotion_with_code) { Spree::Promotion.create! name: 'test1', code: 'code' }

      it 'is expected to not include promotion without code' do
        is_expected.not_to include(promotion_without_code)
      end

      it 'is expected to include promotion with code' do
        is_expected.to include(promotion_with_code)
      end
    end

    describe '.applied' do
      subject { Spree::Promotion.applied }

      let!(:promotion_not_applied) { Spree::Promotion.create! name: 'test', code: '' }
      let(:order) { create(:order) }
      let!(:promotion_applied) do
        promotion = Spree::Promotion.create!(name: 'test1', code: '')
        promotion.orders << order
        promotion
      end

      it 'is expected to not include promotion not applied' do
        is_expected.not_to include(promotion_not_applied)
      end

      it 'is expected to include promotion applied' do
        is_expected.to include(promotion_applied)
      end
    end

    describe '.advertised' do
      subject { Spree::Promotion.advertised }

      let!(:promotion_not_advertised) { Spree::Promotion.create! name: 'test', advertise: false }
      let!(:promotion_advertised) { Spree::Promotion.create! name: 'test1', advertise: true }

      it 'is expected to not include promotion not advertised' do
        is_expected.not_to include(promotion_not_advertised)
      end

      it 'is expected to include promotion advertised' do
        is_expected.to include(promotion_advertised)
      end
    end
  end

  describe '#destroy' do
    let(:promotion) { Spree::Promotion.create(name: 'delete me') }

    before do
      promotion.actions << Spree::Promotion::Actions::CreateAdjustment.new
      promotion.rules << Spree::Promotion::Rules::FirstOrder.new
      promotion.save!
      promotion.destroy
    end

    it 'deletes actions' do
      expect(Spree::PromotionAction.count).to eq(0)
    end

    it 'deletes rules' do
      expect(Spree::PromotionRule.count).to eq(0)
    end
  end

  describe '#save' do
    let(:promotion) { Spree::Promotion.create(name: 'delete me') }

    before do
      promotion.actions << Spree::Promotion::Actions::CreateAdjustment.new
      promotion.rules << Spree::Promotion::Rules::FirstOrder.new
      promotion.save!
    end

    it 'deeply autosaves records and preferences' do
      promotion.actions[0].calculator.preferred_flat_percent = 10
      promotion.save!
      expect(Spree::Calculator.first.preferred_flat_percent).to eq(10)
    end
  end

  describe '#activate' do
    before do
      @action1 = Spree::Promotion::Actions::CreateAdjustment.create!
      @action2 = Spree::Promotion::Actions::CreateAdjustment.create!
      allow(@action1).to receive_messages perform: true
      allow(@action2).to receive_messages perform: true

      promotion.promotion_actions = [@action1, @action2]
      promotion.created_at = 2.days.ago

      @user = stub_model(Spree::LegacyUser, email: 'spree@example.com')
      @order = Spree::Order.create user: @user
      @payload = { order: @order, user: @user }
    end

    it 'checks path if present' do
      promotion.path = 'content/cvv'
      @payload[:path] = 'content/cvv'
      expect(@action1).to receive(:perform).with(@payload)
      expect(@action2).to receive(:perform).with(@payload)
      promotion.activate(@payload)
    end

    it 'does not perform actions against an order in a finalized state' do
      expect(@action1).not_to receive(:perform).with(@payload)

      @order.state = 'complete'
      promotion.activate(@payload)

      @order.state = 'awaiting_return'
      promotion.activate(@payload)

      @order.state = 'returned'
      promotion.activate(@payload)
    end

    it 'does activate if newer then order' do
      expect(@action1).to receive(:perform).with(@payload)
      promotion.created_at = Time.current + 2
      expect(promotion.activate(@payload)).to be true
    end

    context 'keeps track of the orders' do
      context 'when activated' do
        it 'assigns the order' do
          expect(promotion.orders).to be_empty
          expect(promotion.activate(@payload)).to be true
          expect(promotion.orders.first).to eql @order
        end
      end
      context 'when not activated' do
        it 'will not assign the order' do
          @order.state = 'complete'
          expect(promotion.orders).to be_empty
          expect(promotion.activate(@payload)).to be_falsey
          expect(promotion.orders).to be_empty
        end
      end
    end
  end

  context '#usage_limit_exceeded' do
    let(:promotable) { double('Promotable') }

    it 'does not have its usage limit exceeded with no usage limit' do
      promotion.usage_limit = 0
      expect(promotion.usage_limit_exceeded?(promotable)).to be false
    end

    it 'has its usage limit exceeded' do
      promotion.usage_limit = 2
      allow(promotion).to receive_messages(adjusted_credits_count: 2)
      expect(promotion.usage_limit_exceeded?(promotable)).to be true

      allow(promotion).to receive_messages(adjusted_credits_count: 3)
      expect(promotion.usage_limit_exceeded?(promotable)).to be true
    end
  end

  context '#expired' do
    it 'is not exipired' do
      expect(promotion).not_to be_expired
    end

    it "is expired if it hasn't started yet" do
      promotion.starts_at = Time.current + 1.day
      expect(promotion).to be_expired
    end

    it 'is expired if it has already ended' do
      promotion.expires_at = Time.current - 1.day
      expect(promotion).to be_expired
    end

    it 'is not expired if it has started already' do
      promotion.starts_at = Time.current - 1.day
      expect(promotion).not_to be_expired
    end

    it 'is not expired if it has not ended yet' do
      promotion.expires_at = Time.current + 1.day
      expect(promotion).not_to be_expired
    end

    it 'is not expired if current time is within starts_at and expires_at range' do
      promotion.starts_at  = Time.current - 1.day
      promotion.expires_at = Time.current + 1.day
      expect(promotion).not_to be_expired
    end

    it 'is not expired if usage limit is not exceeded' do
      promotion.usage_limit = 2
      allow(promotion).to receive_messages(credits_count: 1)
      expect(promotion).not_to be_expired
    end
  end

  context '#credits_count' do
    let!(:promotion) do
      promotion = Spree::Promotion.new
      promotion.name = 'Foo'
      promotion.code = 'XXX'
      promotion.tap(&:save)
    end

    let!(:action) do
      calculator = Spree::Calculator::FlatRate.new
      action_params = { promotion: promotion, calculator: calculator }
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

    it 'counts eligible adjustments' do
      adjustment.update_column(:eligible, true)
      expect(promotion.credits_count).to eq(1)
    end

    # Regression test for #4112
    it 'does not count ineligible adjustments' do
      adjustment.update_column(:eligible, false)
      expect(promotion.credits_count).to eq(0)
    end
  end

  context '#adjusted_credits_count' do
    let(:order) { create :order }
    let(:line_item) { create :line_item, order: order }
    let(:promotion) { Spree::Promotion.create name: 'promo', code: '10off' }
    let(:order_action) do
      action = Spree::Promotion::Actions::CreateAdjustment.create(calculator: Spree::Calculator::FlatPercentItemTotal.new)
      promotion.actions << action
      action
    end
    let(:item_action) do
      action = Spree::Promotion::Actions::CreateItemAdjustments.create(calculator: Spree::Calculator::FlatPercentItemTotal.new)
      promotion.actions << action
      action
    end
    let(:order_adjustment) do
      Spree::Adjustment.create!(
        source: order_action,
        amount: 10,
        adjustable: order,
        order: order,
        label: 'Promotional adjustment'
      )
    end
    let(:item_adjustment) do
      Spree::Adjustment.create!(
        source: item_action,
        amount: 10,
        adjustable: line_item,
        order: order,
        label: 'Promotional adjustment'
      )
    end

    it 'counts order level adjustments' do
      expect(order_adjustment.adjustable).to eq(order)
      expect(promotion.credits_count).to eq(1)
      expect(promotion.adjusted_credits_count(order)).to eq(0)
    end

    it 'counts item level adjustments' do
      expect(item_adjustment.adjustable).to eq(line_item)
      expect(promotion.credits_count).to eq(1)
      expect(promotion.adjusted_credits_count(order)).to eq(0)
    end
  end

  context '#products' do
    let(:product) { create(:product) }
    let(:promotion) { create(:promotion) }

    context 'when it has product rules with products associated' do
      let(:promotion_rule) { create(:promotion_rule, promotion: promotion, type: 'Spree::Promotion::Rules::Product') }

      before do
        promotion.promotion_rules << promotion_rule
        product.product_promotion_rules.create(promotion_rule_id: promotion_rule.id)
      end

      it 'has products' do
        expect(promotion.reload.products.size).to eq(1)
      end
    end

    context "when there's no product rule associated" do
      it 'does not have products but still return an empty array' do
        expect(promotion.products).to be_blank
      end
    end
  end

  context '#eligible?' do
    subject { promotion.eligible?(promotable) }

    let(:promotable) { create :order }

    context 'when promotion is expired' do
      before { promotion.expires_at = Time.current - 10.days }
      it { is_expected.to be false }
    end

    context 'when promotable is a Spree::LineItem' do
      let(:promotable) { create :line_item }
      let(:product) { promotable.product }

      before do
        product.promotionable = promotionable
      end

      context 'and product is promotionable' do
        let(:promotionable) { true }

        it { is_expected.to be true }
      end

      context 'and product is not promotionable' do
        let(:promotionable) { false }

        it { is_expected.to be false }
      end
    end
    context 'when promotable is a Spree::Order' do
      let(:promotable) { create :order }

      context 'and it is empty' do
        it { is_expected.to be true }
      end

      context 'and it contains items' do
        let!(:line_item) { create(:line_item, order: promotable) }

        context 'and the items are all non-promotionable' do
          before do
            line_item.product.update_column(:promotionable, false)
          end
          it { is_expected.to be false }
        end
        context 'and at least one item is promotionable' do
          it { is_expected.to be true }
        end
      end
    end
  end

  context '#eligible_rules' do
    let(:promotable) { double('Promotable') }

    it 'true if there are no rules' do
      expect(promotion.eligible_rules(promotable)).to eq []
    end

    it 'true if there are no applicable rules' do
      promotion.promotion_rules = [stub_model(Spree::PromotionRule, eligible?: true, applicable?: false)]
      allow(promotion.promotion_rules).to receive(:for).and_return([])
      expect(promotion.eligible_rules(promotable)).to eq []
    end

    context "with 'all' match policy" do
      let(:promo1) { Spree::PromotionRule.create! }
      let(:promo2) { Spree::PromotionRule.create! }

      before { promotion.match_policy = 'all' }

      context 'when all rules are eligible' do
        before do
          allow(promo1).to receive_messages(eligible?: true, applicable?: true)
          allow(promo2).to receive_messages(eligible?: true, applicable?: true)

          promotion.promotion_rules = [promo1, promo2]
          allow(promotion.promotion_rules).to receive(:for).and_return(promotion.promotion_rules)
        end
        it 'returns the eligible rules' do
          expect(promotion.eligible_rules(promotable)).to eq [promo1, promo2]
        end
        it 'does set anything to eligiblity errors' do
          promotion.eligible_rules(promotable)
          expect(promotion.eligibility_errors).to be_nil
        end
      end

      context 'when any of the rules is not eligible' do
        let(:errors) { double(ActiveModel::Errors, empty?: false) }

        before do
          allow(promo1).to receive_messages(eligible?: true, applicable?: true, eligibility_errors: nil)
          allow(promo2).to receive_messages(eligible?: false, applicable?: true, eligibility_errors: errors)

          promotion.promotion_rules = [promo1, promo2]
          allow(promotion.promotion_rules).to receive(:for).and_return(promotion.promotion_rules)
        end
        it 'returns nil' do
          expect(promotion.eligible_rules(promotable)).to be_nil
        end
        it 'sets eligibility errors to the first non-nil one' do
          promotion.eligible_rules(promotable)
          expect(promotion.eligibility_errors).to eq errors
        end
      end
    end

    context "with 'any' match policy" do
      let(:promotion) { Spree::Promotion.create(name: 'Promo', match_policy: 'any') }
      let(:promotable) { double('Promotable') }

      it 'has eligible rules if any of the rules are eligible' do
        allow_any_instance_of(Spree::PromotionRule).to receive_messages(applicable?: true)
        true_rule = Spree::PromotionRule.create(promotion: promotion)
        allow(true_rule).to receive_messages(eligible?: true)
        allow(promotion).to receive_messages(rules: [true_rule])
        allow(promotion).to receive_message_chain(:rules, :for).and_return([true_rule])
        expect(promotion.eligible_rules(promotable)).to eq [true_rule]
      end

      context 'when none of the rules are eligible' do
        let(:promo) { Spree::PromotionRule.create! }
        let(:errors) { double ActiveModel::Errors, empty?: false }

        before do
          allow(promo).to receive_messages(eligible?: false, applicable?: true, eligibility_errors: errors)

          promotion.promotion_rules = [promo]
          allow(promotion.promotion_rules).to receive(:for).and_return(promotion.promotion_rules)
        end
        it 'returns nil' do
          expect(promotion.eligible_rules(promotable)).to be_nil
        end
        it 'sets eligibility errors to the first non-nil one' do
          promotion.eligible_rules(promotable)
          expect(promotion.eligibility_errors).to eq errors
        end
      end
    end
  end

  describe '#line_item_actionable?' do
    subject { promotion.line_item_actionable?(order, line_item) }

    let(:order) { double Spree::Order }
    let(:line_item) { double Spree::LineItem }
    let(:true_rule) { double Spree::PromotionRule, eligible?: true, applicable?: true, actionable?: true }
    let(:false_rule) { double Spree::PromotionRule, eligible?: true, applicable?: true, actionable?: false }
    let(:rules) { [] }

    before do
      allow(promotion).to receive(:rules) { rules }
      allow(rules).to receive(:for) { rules }
    end

    context 'when the order is eligible for promotion' do
      context 'when there are no rules' do
        it { is_expected.to be }
      end

      context 'when there are rules' do
        context 'when the match policy is all' do
          before { promotion.match_policy = 'all' }

          context 'when all rules allow action on the line item' do
            let(:rules) { [true_rule] }

            it { is_expected.to be }
          end

          context 'when at least one rule does not allow action on the line item' do
            let(:rules) { [true_rule, false_rule] }

            it { is_expected.not_to be }
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

            it { is_expected.not_to be }
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
  describe 'normalize blank values for code & path' do
    it 'will save blank value as nil value instead' do
      promotion = Spree::Promotion.create(name: 'A promotion', code: '', path: '')
      expect(promotion.code).to be_nil
      expect(promotion.path).to be_nil
    end
  end

  # Regression test for #4081
  describe '#with_coupon_code' do
    context 'and code stored in uppercase' do
      let!(:promotion) { create(:promotion, :with_order_adjustment, code: 'MY-COUPON-123') }

      it 'finds the code with lowercase' do
        expect(Spree::Promotion.with_coupon_code('my-coupon-123')).to eql promotion
      end
    end

    context 'when promotion has no actions' do
      let!(:promotion_without_actions) { create(:promotion, code: 'MY-COUPON-123').actions.clear }

      it 'then returns the one with an action' do
        expect(Spree::Promotion.with_coupon_code('MY-COUPON-123')).to be_nil
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
        order.update_with_updater!
        order.completed_at = Time.current
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

  describe 'adding items to the cart' do
    let(:order) { create :order }
    let(:line_item) { create :line_item, order: order }
    let(:promo) { create :promotion_with_item_adjustment, adjustment_rate: 5, code: 'promo' }
    let(:variant) { create :variant }

    it 'updates the promotions for new line items' do
      expect(line_item.adjustments).to be_empty
      expect(order.adjustment_total).to eq 0

      promo.activate(order: order)
      order.update_with_updater!

      expect(line_item.adjustments.size).to eq(1)
      expect(order.adjustment_total).to eq(-5)

      other_line_item = Spree::Cart::AddItem.call(order: order, variant: variant, options: { currency: order.currency }).value

      expect(other_line_item).not_to eq line_item
      expect(other_line_item.adjustments.size).to eq(1)
      expect(order.adjustment_total).to eq(-10)
    end
  end

  describe '#generate_code' do
    let(:promotion) { create(:promotion, code: 'spree123') }

    context 'with generate_code' do
      it 'has a generated code' do
        promotion.generate_code = true
        expect(promotion.code).not_to eq 'spree123'
      end
    end

    context 'without generate_code' do
      it 'has a generated code' do
        expect(promotion.code).to eq 'spree123'
      end
    end
  end
end
