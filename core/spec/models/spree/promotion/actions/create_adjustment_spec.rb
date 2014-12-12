require 'spec_helper'

describe Spree::Promotion::Actions::CreateAdjustment, :type => :model do
  let(:order) { create(:order_with_line_items, :line_items_count => 1) }
  let(:promotion) { create(:promotion) }
  let(:action) { Spree::Promotion::Actions::CreateAdjustment.new(calculator: calculator) }
  let(:calculator) { Spree::Calculator::FlatRate.new(preferred_amount: 10) }
  let(:payload) { { order: order } }

  #it_behaves_like 'an adjustment source'

  # From promotion spec:
  context "#perform" do
    before do
      promotion.promotion_actions = [action]
      allow(action).to receive_messages(:promotion => promotion)
    end

    # Regression test for #3966
    it "does not apply an adjustment if the amount is 0" do
      action.calculator.preferred_amount = 0
      action.perform(payload)
      expect(promotion.credits_count).to eq(0)
      expect(order.adjustments.count).to eq(0)
    end

    it "should create a discount with correct negative amount" do
      order.shipments.create!(:cost => 10)

      action.perform(payload)
      expect(promotion.credits_count).to eq(1)
      expect(order.adjustments.count).to eq(1)
      expect(order.adjustments.first.amount.to_i).to eq(-10)
    end

    it "should create a discount accessible through both order_id and adjustable_id" do
      action.perform(payload)
      expect(order.adjustments.count).to eq(1)
      expect(order.all_adjustments.count).to eq(1)
    end

    it "should not create a discount when order already has one from this promotion" do
      order.shipments.create!(:cost => 10)

      action.perform(payload)
      action.perform(payload)
      expect(promotion.credits_count).to eq(1)
    end
  end

  describe '#compute_amount' do
    context 'with accumulator' do
      before do
        allow(order).to receive(:promotion_accumulator).and_return(accumulator)
        allow(action.calculator).to receive(:compute).and_return(10)
      end

      context 'with accumulated total more than calculated amount' do
        let(:accumulator) { double(total_with_promotion: 15) }
        it { expect(action.compute_amount(order)).to eq(-10) }
      end
      context 'with accumulated total less than calculated amount' do
        let(:accumulator) { double(total_with_promotion: 7) }
        it { expect(action.compute_amount(order)).to eq(-7) }
      end
    end
  end

end
