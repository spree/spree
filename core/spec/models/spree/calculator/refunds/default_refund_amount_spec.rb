require 'spec_helper'

describe Spree::Calculator::Returns::DefaultRefundAmount, type: :model do
  let(:line_item_quantity) { 2 }
  let(:price) { 100.0 }
  let(:tax_amount) { 0.2 }
  let(:order) { create(:order) }
  let(:line_item) { create(:line_item, price: price, quantity: line_item_quantity) }
  let(:pre_tax_amount) { line_item.pre_tax_amount }
  let(:inventory_unit) { build(:inventory_unit, order: order, line_item: line_item) }
  let(:return_item) { build(:return_item, inventory_unit: inventory_unit ) }
  let(:calculator) { Spree::Calculator::Returns::DefaultRefundAmount.new }

  before do
    create(:tax_rate, zone: create(:zone, default_tax: true),
                      included_in_price: true,
                      amount: tax_amount)
    order.line_items << line_item
    order.updater.update_totals
  end

  subject { calculator.compute(return_item) }

  context 'not an exchange' do
    context 'no promotions or taxes' do
      it { is_expected.to eq pre_tax_amount / line_item_quantity }
    end

    context 'order adjustments' do
      let(:adjustment_amount) { order.item_total * -0.4 }

      before do
        order.adjustments << create(:adjustment, order: order,
                                                 amount: adjustment_amount,
                                                 eligible: true,
                                                 label: 'Adjustment',
                                                 source_type: 'Spree::Order')
        order.adjustments.first.update_attributes(amount: adjustment_amount)
        order.updater.update_totals
      end

      it { is_expected.to eq (pre_tax_amount - adjustment_amount.abs) / line_item_quantity }

      context 'refund amount * line item quantity with tax applied' do
        subject { (calculator.compute(return_item) * line_item_quantity) * (1 + tax_amount) }
        it { is_expected.to eq order.total }
      end
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

  context 'pre_tax_amount is zero' do
    let(:price)  { 0.0 }
    it { should eq 0.0 }
  end
end
