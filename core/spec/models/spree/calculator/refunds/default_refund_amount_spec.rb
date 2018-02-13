require 'spec_helper'

describe Spree::Calculator::Returns::DefaultRefundAmount, type: :model do
  subject { calculator.compute(return_item) }

  let(:order) { create(:order) }
  let(:line_item_quantity) { 2 }
  let(:item_price)      { 100.0 }
  let(:pre_tax_amount)  { line_item_quantity * item_price }
  let(:line_item)       { create(:line_item, price: item_price, quantity: line_item_quantity) }
  let(:inventory_unit)  { build(:inventory_unit, order: order, line_item: line_item, quantity: 1) }
  let(:return_item)     { build(:return_item, inventory_unit: inventory_unit) }
  let(:calculator)      { Spree::Calculator::Returns::DefaultRefundAmount.new }

  before { order.line_items << line_item }

  context 'not an exchange' do
    context 'no promotions or taxes' do
      it { is_expected.to eq pre_tax_amount / line_item_quantity }
    end

    context 'order adjustments' do
      let(:adjustment_amount) { -10.0 }

      before do
        order.adjustments << create(:adjustment, order: order, amount: adjustment_amount, eligible: true, label: 'Adjustment', source_type: 'Spree::Order')
        order.adjustments.first.update_attributes(amount: adjustment_amount)
      end

      it { is_expected.to eq (pre_tax_amount - adjustment_amount.abs) / line_item_quantity }
    end

    context 'shipping adjustments' do
      let(:adjustment_total) { -50.0 }

      before { order.shipments << Spree::Shipment.new(adjustment_total: adjustment_total) }

      it { is_expected.to eq pre_tax_amount / line_item_quantity }
    end
  end

  context 'an exchange' do
    let(:return_item) { build(:exchange_return_item) }

    it { is_expected.to eq 0.0 }
  end
end
