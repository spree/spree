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

  before do
    order.line_items << line_item
    # written by the tax pass (TaxRate.store_pre_tax_amount) during
    # recalculation: the discounted amount, net of ALL discounts
    line_item.update_column(:pre_tax_amount, pre_tax_amount)
  end

  context 'not an exchange' do
    context 'no promotions or taxes' do
      it { is_expected.to eq pre_tax_amount / line_item_quantity }
    end

    context 'with discounts' do
      let(:discount_amount) { -10.0 }
      # whole-order discounts are distributed to line items and included in
      # pre_tax_amount — the refund needs no separate weighted share
      let(:pre_tax_amount) { line_item_quantity * item_price + discount_amount }

      it { is_expected.to eq (line_item_quantity * item_price - discount_amount.abs) / line_item_quantity }
    end

    context 'fulfillment discounts' do
      before { order.shipments << Spree::Shipment.new(adjustment_total: -50.0) }

      it { is_expected.to eq pre_tax_amount / line_item_quantity }
    end
  end

  context 'an exchange' do
    let(:return_item) { build(:exchange_return_item) }

    it { is_expected.to eq 0.0 }
  end
end
