require 'spec_helper'

describe Spree::Promotion::Actions::CreateAdjustment, :type => :model do
  let(:order) { create(:order_with_line_items) }
  let(:promotion) { create(:promotion, :with_order_adjustment) }
  let(:action) { promotion.actions.first }
  let(:payload) { { order: order } }

  context "#perform" do

    it "should create a discount" do
      action.perform(payload)
      expect(order.adjustments.count).to eq(1)
    end

    it "should create a discount with correct negative amount" do
      action.perform(payload)
      expect(order.adjustments.first.amount.to_i).to eq(-10)
    end

    it "should create a discount with correct associations" do
      action.perform(payload)
      expect(order.adjustments.first.order_id).to eq(order.id)
      expect(order.adjustments.first.adjustable_id).to eq(order.id)
      expect(order.adjustments.first.source_id).to eq(action.id)
    end

    context "with two CreateAdjustment actions" do 
      let(:second_action) { Spree::Promotion::Actions::CreateAdjustment.new(calculator: second_calculator) }
      let(:second_calculator) { action.calculator.dup }

      before do 
        promotion.actions << second_action
        promotion.actions.each { |a| a.perform(payload) }
      end

      context "whose combined discount is larger than item + ship total" do 
        let(:order) { create(:order_with_line_items, shipment_cost: 5) }

        it "should create two discounts that together equal the item + ship total" do
          expect(order.adjustments.map(&:amount).reduce(&:+)).to eq(-1 * (order.item_total + order.ship_total))
        end
      end

      context 'with the second action using the FlatPercentItemTotal calculator' do
        let(:order) { create(:order_with_line_items, line_items_price: 25) }
        let(:second_calculator) { Spree::Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10) }

        it 'should calculate the second discount as a percentage of the total after the first discount is applied' do 
          expect(order.adjustments[1].amount).to eq(-1.5)
        end
      end
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
