require 'spec_helper'

describe Spree::Promotion::Actions::CreateAdjustment, :type => :model do
  let(:order) { create(:order_with_line_items, :line_items_count => 1) }
  let(:promotion) { create(:promotion) }
  let(:action) { Spree::Promotion::Actions::CreateAdjustment.new }
  let(:payload) { { order: order } }

  # From promotion spec:
  context "#perform" do
    before do
      action.calculator = Spree::Calculator::FlatRate.new(:preferred_amount => 10)
      promotion.promotion_actions = [action]
      allow(action).to receive_messages(:promotion => promotion)
    end

    # Regression test for #3966
    it "does not apply an adjustment if the amount is 0" do
      action.calculator.preferred_amount = 0
      action.calculator.save
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

  context "#destroy" do
    before(:each) do
      action.calculator = Spree::Calculator::FlatRate.new(:preferred_amount => 10)
      promotion.promotion_actions = [action]
    end

    context "when order is not complete" do
      it "should not keep the adjustment" do
        action.perform(payload)
        action.destroy
        expect(order.adjustments.count).to eq(0)
      end
    end

    context "when order is complete" do
      let(:order) do
        create(:completed_order_with_totals, :line_items_count => 1)
      end

      before(:each) do
        action.perform(payload)
        action.destroy
      end

      it "should keep the adjustment" do
        expect(order.adjustments.count).to eq(1)
      end

      it "should nullify the adjustment source" do
        expect(order.adjustments.reload.first.source).to be_nil
      end
    end
  end
end
