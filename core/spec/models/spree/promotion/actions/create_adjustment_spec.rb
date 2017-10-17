require 'spec_helper'

describe Spree::Promotion::Actions::CreateAdjustment, type: :model do
  let(:order) { create(:order_with_line_items, line_items_count: 1) }
  let(:promotion) { create(:promotion) }
  let(:action) { Spree::Promotion::Actions::CreateAdjustment.new }
  let(:payload) { { order: order } }

  it_behaves_like 'an adjustment source'

  describe '#compute_amount' do
    subject { described_class.new }

    let(:shipping_discount) { 10 }
    let(:order) do
      double(:order, item_total: 30, ship_total: 10, shipping_discount: shipping_discount)
    end

    context 'when shipping_discount is applied' do
      context 'and total is less than discount' do
        it 'returns discount amount eq to total' do
          allow(subject).to receive(:compute).with(order).and_return(100)

          expect(subject.compute_amount(order)).to eq -30
        end
      end

      context 'and total is equal to discount' do
        it 'returns discount amount' do
          allow(subject).to receive(:compute).with(order).and_return(30)

          expect(subject.compute_amount(order)).to eq -30
        end
      end

      context 'and total is greater than discount' do
        it 'returns discount amount' do
          allow(subject).to receive(:compute).with(order).and_return(10)

          expect(subject.compute_amount(order)).to eq -10
        end
      end
    end

    context 'when shipping_discount is not applied' do
      let(:shipping_discount) { 0 }

      context 'and total is less than discount' do
        it 'returns discount amount eq to total' do
          allow(subject).to receive(:compute).with(order).and_return(100)

          expect(subject.compute_amount(order)).to eq -40
        end
      end

      context 'and total is equal to discount' do
        it 'returns discount amount' do
          allow(subject).to receive(:compute).with(order).and_return(40)

          expect(subject.compute_amount(order)).to eq -40
        end
      end

      context 'and total is greater than discount' do
        it 'returns discount amount' do
          allow(subject).to receive(:compute).with(order).and_return(10)

          expect(subject.compute_amount(order)).to eq -10
        end
      end
    end
  end

  # From promotion spec:
  context '#perform' do
    before do
      action.calculator = Spree::Calculator::FlatRate.new(preferred_amount: 10)
      promotion.promotion_actions = [action]
      allow(action).to receive_messages(promotion: promotion)
    end

    # Regression test for #3966
    it 'does not apply an adjustment if the amount is 0' do
      action.calculator.preferred_amount = 0
      action.perform(payload)
      expect(promotion.usage_count).to eq(0)
      expect(order.adjustments.count).to eq(0)
    end

    it 'should create a discount with correct negative amount' do
      order.shipments.create!(cost: 10, stock_location: create(:stock_location))

      action.perform(payload)
      expect(promotion.usage_count).to eq(1)
      expect(order.adjustments.count).to eq(1)
      expect(order.adjustments.first.amount.to_i).to eq(-10)
    end

    it 'should create a discount accessible through both order_id and adjustable_id' do
      action.perform(payload)
      expect(order.adjustments.count).to eq(1)
      expect(order.all_adjustments.count).to eq(1)
    end

    it 'should not create a discount when order already has one from this promotion' do
      order.shipments.create!(cost: 10, stock_location: create(:stock_location))

      action.perform(payload)
      action.perform(payload)
      expect(promotion.usage_count).to eq(1)
    end

    context 'when a promotion code is used' do
      let(:promotion_code) { create(:promotion_code) }
      let(:promotion) { promotion_code.promotion }
      let(:payload) { { order: order, promotion_code: promotion_code } }

      it 'should connect the adjustment to the promotion_code' do
        expect {
          action.perform(payload)
        }.to change { order.adjustments.count }.by(1)
        expect(order.adjustments.last.promotion_code).to eq promotion_code
      end
    end
  end
end
