require 'spec_helper'

shared_context 'a default refund calculator' do
  let(:line_item_quantity) { 2 }
  let(:line_item_price) { 100.0 }
  let(:tax_amount) { 0.2 }
  let(:order) { create(:order) }

  let(:tax_rate) do
    create(:tax_rate, zone: create(:zone, default_tax: true),
                      included_in_price: tax_included_in_price,
                      amount: tax_amount)
  end

  let(:inventory_unit) { build(:inventory_unit, order: order, line_item: line_item) }

  let(:return_item) { build(:return_item, inventory_unit: inventory_unit) }

  let(:calculator) { Spree::Calculator::Returns::DefaultRefundAmount.new }

  before(:each) do
    tax_rate
    order.line_items << line_item
    order.updater.update_totals
  end

  subject { calculator.compute(return_item) }

  context 'not an exchange' do
    context 'no promotions or taxes' do
      it { is_expected.to eq pre_tax_amount / line_item_quantity }
    end

    context 'order adjustments' do
      let(:promotion_action) do
        calculator = Spree::Calculator::FlatPercentItemTotal.new
        calculator.preferred_flat_percent = 40
        Spree::Promotion::Actions::CreateAdjustment.create!(calculator: calculator,
                                                            promotion: create(:promotion))
      end

      let(:adjustment_amount) { order.item_total * -0.4 }

      before(:each) do
        promotion_action.perform(order: order)
        order.save!
        order.updater.update_totals
      end

      it { is_expected.to be_within(0.001).of(adjustment_refund_amount) }

      context 'refund amount * line item quantity with tax applied' do
        subject { full_refund_amount }
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
    let(:line_item_price)  { 0.0 }
    it { should eq 0.0 }
  end
end

describe Spree::Calculator::Returns::DefaultRefundAmount, type: :model do
  context 'tax included in price' do
    let(:tax_included_in_price) { true }
    let(:pre_tax_amount) { line_item.pre_tax_amount }

    let(:line_item) { create(:line_item, price: line_item_price, quantity: line_item_quantity) }

    let(:adjustment_refund_amount) do
      (line_item_price + (adjustment_amount / 2)) / (1 + tax_amount)
    end

    let(:full_refund_amount) do
      (calculator.compute(return_item) * (1 + tax_amount)).round * line_item_quantity
    end

    it_should_behave_like 'a default refund calculator'
  end

  context 'tax additional to price' do
    let(:tax_included_in_price) { false }
    let(:pre_tax_amount) { line_item_price * line_item_quantity }

    let(:line_item) { create(:line_item, price: line_item_price,
                                         quantity: line_item_quantity,
                                         pre_tax_amount: pre_tax_amount) }

    let(:adjustment_refund_amount) do
      (pre_tax_amount - adjustment_amount.abs) / line_item_quantity
    end

    let(:full_refund_amount) do
      (calculator.compute(return_item) * line_item_quantity) + order.additional_tax_total
    end

    it_should_behave_like 'a default refund calculator'
  end
end
