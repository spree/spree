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

    context 'with a discount on the line item' do
      let(:discount_amount) { -10.0 }

      before do
        create(:discount, order: order, line_item: line_item, amount: discount_amount, label: 'Discount', kind: 'manual')
        order.recalculate_totals!
        line_item.reload
      end

      it { is_expected.to eq (pre_tax_amount - discount_amount.abs) / line_item_quantity }
    end

    context 'with a fulfillment-level discount' do
      let!(:shipment) { create(:shipment, order: order, cost: 50) }

      before do
        create(:discount, order: order, fulfillment: shipment, amount: -50, label: 'Free shipping', kind: 'promotion')
        order.recalculate_totals!
      end

      it 'does not affect the line item refund' do
        is_expected.to eq pre_tax_amount / line_item_quantity
      end
    end
  end

  context 'an exchange' do
    let(:return_item) { build(:exchange_return_item) }

    it { is_expected.to eq 0.0 }
  end
end
